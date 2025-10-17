require "async"
require "async/redis"
require "async/redis/cluster_client"

module ActiveSupport
  module Cache
    class AsyncRedisCacheStore < Store
      DEFAULT_SCAN_BATCH = 1_000
      DEFAULT_ERROR_HANDLER = ->(method:, returning:, exception:) do
        # no-op by default (same default semantics as RedisCacheStore);
        # applications may inject a handler to log/track errors.
      end

      # Advertise cache versioning support.
      def self.supports_cache_versioning?
        true
      end

      prepend Strategy::LocalCache

      attr_reader :client

      # Options parity with RedisCacheStore where possible.
      # Recognized options:
      #   :url => String or Array[String]
      #   :cluster => bool (use Async::Redis::ClusterClient)
      #   :connect_timeout, :read_timeout, :write_timeout
      #   :reconnect_attempts => Integer
      #   :error_handler => proc(method:, returning:, exception:)
      #   :pool => true/false/{ size: Integer }
      #     When present (or omitted), behaves like RedisCacheStore and limits
      #     the async-redis connection pool size. Defaults to { size: 5 }.
      #     When set to false/nil, no pool limit is applied (unbounded).
      def initialize(error_handler: DEFAULT_ERROR_HANDLER, reconnect_attempts: 1, **opts)
        cache_opts = opts.extract!(*UNIVERSAL_OPTIONS)

        @error_handler = error_handler
        @reconnect_attempts = Integer(reconnect_attempts)

        # Parse :pool like ActiveSupport::Cache::Store does to keep parity with
        # RedisCacheStore semantics. This returns either false/nil, or a Hash
        # including :size and :timeout (we ignore :timeout here).
        pool_options = ActiveSupport::Cache::Store.send(:retrieve_pool_options, opts)
        limit = case pool_options
        when false, nil
          nil
        else
          Integer(pool_options[:size])
        end

        urls = Array(opts.delete(:url)).compact
        use_cluster = opts.delete(:cluster)

        # Map Rails' split timeouts to async-redis' single timeout.
        timeouts = [ opts.delete(:connect_timeout), opts.delete(:read_timeout), opts.delete(:write_timeout) ].compact
        timeout = timeouts.max

        # Thread the computed pool limit through to the async-redis client(s).
        @client = build_client(urls: urls, cluster: use_cluster, timeout: timeout, limit: limit, **opts)

        super(cache_opts)
      end

      def inspect
        "#<#{self.class} options=#{options.inspect}>"
      end

      # ------- Cache Store API -------

      def read_entry(name, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)
        raw = options&.fetch(:raw, false)

        serialized = read_serialized_entry(key, raw: raw)
        return unless serialized

        entry = deserialize_entry(serialized, raw: raw)
        return unless entry
        return if entry.expired?
        return if entry.mismatched?(normalize_version(name, options))

        entry
      end

      def delete_matched(matcher, options = nil)
        unless String === matcher
          raise ArgumentError, "Only Redis glob strings are supported: #{matcher.inspect}"
        end

        # Build a namespaced Redis glob string (not a Regexp) to pass to SCAN MATCH.
        pattern = namespace_key(matcher, merged_options(options))

        instrument :delete_matched, pattern do
          scan_delete_pattern(pattern)
        end
      end

      def increment(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        instrument :increment, key, amount: amount do
          failsafe(:increment) do
            change_counter(key, amount, options)
          end
        end
      end

      def decrement(name, amount = 1, options = nil)
        options = merged_options(options)
        key = normalize_key(name, options)

        instrument :decrement, key, amount: amount do
          failsafe(:decrement) do
            change_counter(key, -amount, options)
          end
        end
      end

      # Change numeric counter stored at +key+ by +amount+ and manage TTL if provided.
      def change_counter(key, amount, options)
        expires_in = options[:expires_in]

        count = call_redis { |c| c.call("INCRBY", key, Integer(amount)) }

        if expires_in
          if supports_expire_nx?
            # Only set expiry if it wasn't already set:
            call_redis { |c| c.call("EXPIRE", key, expires_in.to_i, "NX") }
          else
            ttl = call_redis { |c| c.call("TTL", key) }
            call_redis { |c| c.call("EXPIRE", key, expires_in.to_i) } if ttl.to_i < 0
          end
        end

        count
      end

      # Detect if Redis supports EXPIRE key seconds NX (Redis 7+).
      def supports_expire_nx?
        return @supports_expire_nx if defined?(@supports_expire_nx)

        versions = []
        each_client do |c|
          info = c.call("INFO", "server")
          # Parse 'redis_version:7.2.5' line from INFO string:
          if info.is_a?(String)
            versions << (info[/redis_version:(\d+\.\d+\.\d+)/, 1])
          elsif info.respond_to?(:to_s)
            s = info.to_s
            versions << (s[/redis_version:(\d+\.\d+\.\d+)/, 1])
          end
        end
        versions.compact!
        @supports_expire_nx = !versions.empty? && versions.all? { |v| Gem::Version.new(v) >= Gem::Version.new("7.0.0") }
      end

      def cleanup(options = nil)
        super
      end

      def clear(options = nil)
        failsafe :clear do
          ns = merged_options(options)[:namespace]
          if ns
            delete_matched("*", namespace: ns)
          else
            each_client { |c| c.call("FLUSHDB") }
          end
        end
      end

      def stats
        collect_per_node("server") { |c| c.call("INFO") }
      end

      private

        # Build single, distributed, or cluster client.
        def build_client(urls:, cluster:, timeout:, limit: nil, **opts)
          if urls.size <= 1
            endpoint = if urls.empty?
              ::Async::Redis::Endpoint.local
            else
              ::Async::Redis::Endpoint.parse(urls.first, timeout: timeout)
            end
            return ::Async::Redis::Client.new(endpoint, limit: limit)
          end

          endpoints = urls.map { |u| ::Async::Redis::Endpoint.parse(u, timeout: timeout) }

          if cluster
            # ClusterClient uses endpoints that contain their own timeout settings.
            ::Async::Redis::ClusterClient.new(endpoints, limit: limit)
          else
            ::AsyncRedisCacheStore::AsyncDistributed.new(endpoints, limit: limit)
          end
        end

        def each_client(&blk)
          if distributed?
            client.each_client(&blk)
          elsif cluster?
            cluster_each_client(&blk)
          else
            blk.call(client)
          end
        end

        def collect_per_node(_section = nil)
          results = []
          each_client do |c|
            results << yield(c)
          end
          results
        end

        def distributed?
          client.is_a?(::AsyncRedisCacheStore::AsyncDistributed)
        end

        def cluster?
          defined?(::Async::Redis::ClusterClient) && client.is_a?(::Async::Redis::ClusterClient)
        end

        # Implementation of Cache Store operations (read/write/delete, etc.)
        # Only the parts that reference Redis are shown here for brevity; the full implementation
        # should mirror the version in the application repository.

        def read_serialized_entry(key, raw: false, **_)
          failsafe :read_entry do
            if cluster?
              result = nil
              client.clients_for(key) { |c, _| result = c.call("GET", key) }
              result
            else
              call_redis { |c| c.call("GET", key) }
            end
          end
        end

        def write_entry(key, entry, raw: false, **options)
          write_serialized_entry(key, serialize_entry(entry, raw: raw, **options), raw: raw, **options)
        end

        def write_serialized_entry(key, payload, raw: false, unless_exist: false, expires_in: nil, race_condition_ttl: nil, pipeline: nil, **options)
          if race_condition_ttl && expires_in && expires_in > 0 && !raw
            expires_in += 5.minutes
          end

          modifiers = {}
          if unless_exist || expires_in
            modifiers[:nx] = unless_exist
            modifiers[:px] = (1000 * expires_in.to_f).ceil if expires_in
          end

          if pipeline
            # async-redis pipeline doesn't accept keyword modifiers for SET; build args:
            args = [ "SET", key, payload ]
            args << "NX" if unless_exist
            args.concat([ "PX", (1000 * expires_in.to_f).ceil ]) if expires_in
            pipeline.call(*args)
          else
            failsafe :write_entry, returning: nil do
              call_redis do |c|
                args = [ "SET", key, payload ]
                args << "NX" if unless_exist
                args.concat([ "PX", (1000 * expires_in.to_f).ceil ]) if expires_in
                !!c.call(*args)
              end
            end
          end
          end

        # Raw values are written as strings; non-raw use base serializer.
        def serialize_entry(entry, raw: false, **options)
          if raw
            entry.value.to_s
          else
            super(entry, raw: raw, **options)
          end
        end

        def serialize_entries(entries, **options)
          entries.transform_values do |entry|
            serialize_entry(entry, **options)
          end
        end

        def delete_entry(key, **)
          failsafe :delete_entry, returning: false do
            call_redis { |c| c.call("UNLINK", key) > 0 }
          end
        end

        def delete_multi_entries(keys, **)
          return if keys.empty?
          failsafe :delete_multi_entries do
            call_redis { |c| c.call("UNLINK", *keys) }
          end
        end

        def read_multi_entries(names, **options)
          options = merged_options(options)
          return {} if names.empty?

          raw = options&.fetch(:raw, false)
          keys = names.map { |n| normalize_key(n, options) }

          values_by_key = mget_by_group(keys)

          names.each_with_object({}) do |name, acc|
            key = normalize_key(name, options)
            value = values_by_key[key]
            next unless value
            entry = deserialize_entry(value, raw: raw)
            next if entry.nil? || entry.expired? || entry.mismatched?(normalize_version(name, options))
            begin
              acc[name] = entry.value
            rescue DeserializationError
              # treat as miss
            end
          end
        end

        def write_multi_entries(entries, **options)
          return if entries.empty?

          if distributed?
            grouped = entries.group_by { |key, _| client.client_for_key(key) }
            grouped.each do |c, sub_entries|
              c.pipeline do |pipe|
                sub_entries.each do |key, entry|
                  write_entry(key, entry, **options.merge(pipeline: pipe))
                end
              end
            end
          elsif cluster?
            client.clients_for(*entries.keys) do |c, sub|
              c.pipeline do |pipe|
                sub.each do |key|
                  entry = entries[key]
                  write_entry(key, entry, **options.merge(pipeline: pipe))
                end
              end
            end
          else
            call_redis do |c|
              c.pipeline do |pipe|
                entries.each do |key, entry|
                  write_entry(key, entry, **options.merge(pipeline: pipe))
                end
              end
            end
          end
        end

        def mget_by_group(keys)
          if distributed?
            groups = client.group_by_client(keys)
            values_by_key = {}
            groups.each do |c, sub|
              values = c.call("MGET", *sub)
              sub.each_with_index { |k, i| values_by_key[k] = values[i] }
            end
            values_by_key
          elsif cluster?
            values_by_key = {}
            client.clients_for(*keys) do |c, sub|
              values = c.call("MGET", *sub)
              sub.each_with_index { |k, i| values_by_key[k] = values[i] }
            end
            values_by_key
          else
            values = client.call("MGET", *keys)
            keys.each_with_index.each_with_object({}) { |(k, i), acc| acc[k] = values[i] }
          end
        end

        def scan_delete_pattern(pattern)
          each_client do |c|
            cursor = "0"
            begin
              cursor, keys = c.call("SCAN", cursor, "MATCH", pattern, "COUNT", DEFAULT_SCAN_BATCH)
              c.call("UNLINK", *keys) unless keys.nil? || keys.empty?
            end until cursor == "0"
          rescue => e
            @error_handler&.call(method: :delete_matched, returning: nil, exception: e)
          end
        end

        # Calls a Redis operation with minimal retry handling.
        def call_redis
          attempts = @reconnect_attempts
          begin
            # In non-async contexts, ensure a scheduler exists
            if async_context?
              yield(client_for_current_context)
            else
              Sync { yield(client_for_current_context) }
            end
          rescue => e
            attempts -= 1
            if attempts > 0
              Async::Task.current.sleep(0.05)
              retry
            else
              raise e
            end
          end
        end

        def client_for_current_context
          client
        end

        def failsafe(method, returning: nil)
          yield
        rescue ::Async::TimeoutError, IOError, SystemCallError, ::Protocol::Redis::ServerError, OpenSSL::SSL::SSLError => error
          @error_handler&.call(method: method, exception: error, returning: returning)
          returning
        end

        # --- Cluster helpers ---
        def cluster_each_client
          any = client.any_client
          shards = any.call("CLUSTER", "SHARDS")
          endpoints = []
          shards.each do |shard|
            hash = shard.each_slice(2).to_h
            hash["nodes"].each do |node|
              node = node.each_slice(2).to_h
              endpoints << ::Async::Redis::Endpoint.for(any.endpoint.scheme, node["endpoint"], port: node["port"])
            end
          end
          endpoints.uniq.each do |ep|
            c = ::Async::Redis::Client.new(ep)
            begin
              yield c
            ensure
              c.close
            end
          end
        end

        def async_context?
          !!Async::Task.current?
        rescue
          false
        end
    end
  end
end

# Minimal distributed client wrapper for multi-endpoint (non-cluster) mode.
require_relative "../../async_redis_cache_store/async_distributed"
