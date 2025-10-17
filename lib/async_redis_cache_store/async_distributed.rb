# frozen_string_literal: true

# Minimal async-redis equivalent of Redis::Distributed used by the async cache store.
# Goals:
# - Deterministic key placement identical to redis-rb's Redis::Distributed
#   (supports hash tags via {tag} and consistent hash ring).
# - Keep implementation tiny and focused only on what's needed by the cache store.

require "async/redis"
require "zlib"

module AsyncRedisCacheStore
  class HashRing
    POINTS_PER_SERVER = 160

    Node = Struct.new(:name, :client) do
      def to_s
        name
      end
    end

    def initialize(nodes = [], replicas: POINTS_PER_SERVER)
      @replicas = replicas
      @ring = {}
      @sorted_keys = []
      nodes.each { |n| add_node(n) }
    end

    def add_node(node)
      @replicas.times do |i|
        key = Zlib.crc32("#{node}-#{i}")
        @ring[key] = node
        @sorted_keys << key
      end
      @sorted_keys.sort!
    end

    def get_node(key)
      return nil if @ring.empty?
      hash = Zlib.crc32(key.to_s)
      idx = @sorted_keys.bsearch_index { |x| x >= hash } || 0
      @ring[@sorted_keys[idx]]
    end
  end

  # A tiny distributed router over multiple Async::Redis::Client instances.
  class AsyncDistributed
    TAG = /\{(.+?)\}/.freeze

    def initialize(endpoints, limit: nil)
      @clients = endpoints.map.with_index do |endpoint, i|
        client = ::Async::Redis::Client.new(endpoint, limit: limit)
        HashRing::Node.new("node-#{i}", client)
      end

      @ring = HashRing.new(@clients)
    end

    # Choose client for a key using the same tag logic as Redis::Distributed.
    def client_for_key(key)
      key = key.to_s
      if (m = TAG.match(key)) && m[1] && !m[1].empty?
        key = m[1]
      end
      node = @ring.get_node(key)
      node&.client
    end

    # Group keys by client.
    def group_by_client(keys)
      groups = Hash.new { |h, k| h[k] = [] }
      keys.each do |k|
        c = client_for_key(k)
        groups[c] << k
      end
      groups
    end

    # Iterate all clients.
    def each_client(&blk)
      @clients.each { |n| blk.call(n.client) }
    end

    # Close all clients.
    def close
      each_client { |c| c.close }
    end

    # Minimal routing for top-level calls used by the cache store when operating
    # on the distributed wrapper directly.
    def call(command, *args)
      cmd = command.to_s.upcase
      case cmd
      when "UNLINK"
        keys = args
        groups = group_by_client(keys)
        total = 0
        groups.each do |cli, sub|
          next if sub.nil? || sub.empty?
          total += (cli.call("UNLINK", *sub) || 0)
        end
        total
      else
        # Best-effort routing for single-key commands:
        if args && !args.empty?
          key = args.first
          if (cli = client_for_key(key))
            return cli.call(cmd, *args)
          end
        end
        # Fallback to first client if nothing else:
        first = @clients.first&.client
        first ? first.call(cmd, *args) : nil
      end
    end
  end
end
