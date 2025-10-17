# frozen_string_literal: true

require "cache_store_context"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include_context CacheStoreContext

  it "uses namespace option in configuration" do
    store_with_ns = ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url, namespace: "test_namespace", pool: { size: 5 })

    # Verify the store accepts the namespace option
    expect(store_with_ns.options[:namespace]).to be == "test_namespace"

    key = test_key
    store_with_ns.write(key, "value", expires_in: 10)

    # The key should exist under the namespace
    # We can't easily verify the exact Redis key, but we can verify write/delete works
    expect(store_with_ns.delete(key)).to be == true
  end

  it "clears only keys in the specified namespace" do
    url_local = ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0")
    store_ns = ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url_local, namespace: "test_ns")
    store_default = ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url_local)

    key = test_key
    store_ns.write(key, "ns_value", expires_in: 10)
    store_default.write(key, "default_value", expires_in: 10)

    store_ns.clear

    expect(store_ns.read(key)).to be_nil
    expect(store_default.read(key)).to be == "default_value"
  ensure
    store_default&.delete(key)
  end
end
