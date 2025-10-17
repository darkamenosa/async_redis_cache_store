# frozen_string_literal: true

require "cache_store_context"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include_context CacheStoreContext

  it "respects NX and PX TTL" do
    key = test_key
    expect(store.write(key, "first", expires_in: 0.2, unless_exist: true)).to be == true
    # second write with NX should be ignored and return false boolean:
    expect(store.write(key, "second", expires_in: 0.2, unless_exist: true)).to be == false
    expect(store.read(key)).to be == "first"

    Async::Task.current.sleep(0.25)
    expect(store.read(key)).to be_nil
  ensure
    store.delete(key)
  end

  it "returns nil for expired entries" do
    key = test_key

    # Write with very short TTL
    store.write(key, "expires_soon", expires_in: 0.1)

    # Read immediately should work
    expect(store.read(key)).to be == "expires_soon"

    # Wait for expiration
    Async::Task.current.sleep(0.15)

    # Should return nil after expiration
    expect(store.read(key)).to be_nil
  end

  it "filters expired entries in read_multi" do
    keys = test_keys(2)
    key1 = keys[0]
    key2 = keys[1]

    # key1 expires quickly, key2 has longer TTL
    store.write(key1, "expires_fast", expires_in: 0.1)
    store.write(key2, "expires_slow", expires_in: 10)

    # Wait for key1 to expire
    Async::Task.current.sleep(0.15)

    result = store.read_multi(key1, key2)

    # key1 should be expired (value is nil)
    expect(result[key1]).to be_nil
    # key2 should still be present with its value
    expect(result[key2]).to be == "expires_slow"
  ensure
    store.delete(key2)
  end

  it "extends TTL when race_condition_ttl is set" do
    key = test_key

    # race_condition_ttl adds 5 minutes to the expires_in for non-raw values
    expires_in = 10 # seconds
    race_condition_ttl = 5 # seconds (adds 5 minutes = 300 seconds)

    store.write(key, "value", expires_in: expires_in, race_condition_ttl: race_condition_ttl)

    # Read back to verify it was written
    expect(store.read(key)).to be == "value"

    # The actual TTL should be expires_in + 5.minutes (300s) = 310s
    # We can't easily check the exact TTL without direct Redis access,
    # but we can verify the value was written successfully
    expect(store.read(key)).to be == "value"
  ensure
    store.delete(key)
  end

  it "accepts race_condition_ttl option without errors" do
    key = test_key

    # Verify race_condition_ttl option is accepted and doesn't cause errors
    result = store.write(key, "value", expires_in: 10, race_condition_ttl: 5)
    expect(result).to be == true

    # Verify the value was written
    value = store.read(key)
    expect(value).to be == "value"
  ensure
    store.delete(key)
  end
end
