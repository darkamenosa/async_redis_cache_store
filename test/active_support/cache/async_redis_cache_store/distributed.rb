# frozen_string_literal: true

require "cache_store_context"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include_context CacheStoreContext

  it "writes and reads using distributed mode (two endpoints)" do
    store_dist = ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: [ url, url ], pool: { size: 5 })

    keys = test_keys(5)
    values = keys.map { |k| [ k, "value-#{k.split(":").last}" ] }.to_h

    store_dist.write_multi(values, expires_in: 5)
    result = store_dist.read_multi(*keys)
    expect(result.size).to be == keys.size
    keys.each { |k| expect(result[k]).to be =~ /value-/ }
  ensure
    store_dist&.delete_multi(keys) if defined?(store_dist)
  end

  it "routes keys with hash tags to the same node in distributed mode" do
    store_dist = ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: [ url, url ], pool: { size: 5 })

    distributed_client = store_dist.instance_variable_get(:@client)

    # Keys with the same hash tag {user:123} should route to the same node
    key1 = "cache:{user:123}:profile"
    key2 = "cache:{user:123}:settings"
    key3 = "cache:other:data"

    client1 = distributed_client.client_for_key(key1)
    client2 = distributed_client.client_for_key(key2)
    client3 = distributed_client.client_for_key(key3)

    # key1 and key2 should route to the same client because of {user:123}
    expect(client1).to be == client2

    # Write and read values to verify routing works
    values = {
      key1 => "profile_data",
      key2 => "settings_data",
      key3 => "other_data"
    }

    store_dist.write_multi(values, expires_in: 10)
    result = store_dist.read_multi(key1, key2, key3)

    expect(result[key1]).to be == "profile_data"
    expect(result[key2]).to be == "settings_data"
    expect(result[key3]).to be == "other_data"
  ensure
    store_dist&.delete_multi([ key1, key2, key3 ]) if defined?(store_dist)
  end

  it "handles keys with empty hash tags" do
    store_dist = ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: [ url, url ], pool: { size: 5 })
    distributed_client = store_dist.instance_variable_get(:@client)

    # Empty hash tag {} should use the full key for routing
    key = "cache:{}:empty"
    client = distributed_client.client_for_key(key)

    # Client should be assigned (not nil)
    expect(client.class.name).to be =~ /Redis/

    store_dist.write(key, "value", expires_in: 10)
    expect(store_dist.read(key)).to be == "value"
  ensure
    store_dist&.delete(key) if defined?(store_dist)
  end
end
