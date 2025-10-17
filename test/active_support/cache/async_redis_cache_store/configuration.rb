# frozen_string_literal: true

require "cache_store_context"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include_context CacheStoreContext

  it "works with unbounded pool (pool: false)" do
    store_unbounded = ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url, pool: false)

    key = test_key
    store_unbounded.write(key, "value", expires_in: 10)
    expect(store_unbounded.read(key)).to be == "value"
  ensure
    store_unbounded&.delete(key) if defined?(store_unbounded)
  end

  it "works with custom pool size" do
    store_custom = ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url, pool: { size: 10 })

    key = test_key
    store_custom.write(key, "value", expires_in: 10)
    expect(store_custom.read(key)).to be == "value"
  ensure
    store_custom&.delete(key) if defined?(store_custom)
  end

  it "works with default pool size when pool option is omitted" do
    store_default = ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url)

    key = test_key
    store_default.write(key, "value", expires_in: 10)
    expect(store_default.read(key)).to be == "value"
  ensure
    store_default&.delete(key) if defined?(store_default)
  end

  it "works with timeout configurations" do
    store_timeout = ActiveSupport::Cache.lookup_store(
      :async_redis_cache_store,
      url: url,
      connect_timeout: 5,
      read_timeout: 10,
      write_timeout: 10,
      pool: { size: 5 }
    )

    key = test_key
    store_timeout.write(key, "value", expires_in: 10)
    expect(store_timeout.read(key)).to be == "value"
  ensure
    store_timeout&.delete(key) if defined?(store_timeout)
  end
end
