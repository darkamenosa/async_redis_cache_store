# frozen_string_literal: true

require "sus/fixtures/async"
require "active_support/cache"
require "securerandom"
require "async_redis_cache_store"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include Sus::Fixtures::Async::ReactorContext

  let(:url) { ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") }

  it "writes and reads using distributed mode (two endpoints)" do
    store = ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: [url, url], pool: { size: 5 })

    keys = Array.new(5) { |i| "sus:dist:#{i}:#{SecureRandom.hex(2)}" }
    values = keys.map { |k| [k, "v-#{k.split(":")[2]}" ] }.to_h

    store.write_multi(values, expires_in: 5)
    result = store.read_multi(*keys)
    expect(result.size).to be == keys.size
    keys.each { |k| expect(result[k]).to be =~ /v-/ }
  ensure
    store&.delete_multi(keys) if defined?(store)
  end
end

