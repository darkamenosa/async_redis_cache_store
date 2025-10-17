# frozen_string_literal: true

require "cache_store_context"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include_context CacheStoreContext

  it "increments and decrements a counter" do
    key = test_key
    expect(store.write(key, 0, raw: true, expires_in: 10)).to be == true
    expect(store.increment(key, 2)).to be == 2
    expect(store.decrement(key, 1)).to be == 1
  ensure
    store.delete(key)
  end

  it "handles raw integers in counters with increment and decrement" do
    key = test_key

    # Write raw integer
    result = store.write(key, 100, raw: true, expires_in: 10)
    expect(result).to be == true

    # Increment should work and return the new value
    incremented = store.increment(key, 50)
    expect(incremented).to be == 150

    # Decrement should also work
    decremented = store.decrement(key, 25)
    expect(decremented).to be == 125
  ensure
    store.delete(key)
  end

  it "handles counter with expires_in and increment" do
    key = test_key

    # Initialize counter without expires_in
    result = store.write(key, 0, raw: true)
    expect(result).to be == true

    # Increment with expires_in should set TTL and return new value
    incremented = store.increment(key, 1, expires_in: 10)
    expect(incremented).to be == 1

    # Multiple increments should work
    second_increment = store.increment(key, 2)
    expect(second_increment).to be == 3
  ensure
    store.delete(key)
  end

  it "writes raw values for counters and can increment them" do
    keys = test_keys(3)

    # Write raw numeric values (used for counters)
    keys.each do |k|
      result = store.write(k, 10, raw: true, expires_in: 10)
      expect(result).to be == true
    end

    # Verify we can increment these values
    keys.each do |k|
      result = store.increment(k, 5)
      expect(result).to be == 15
    end
  ensure
    store.delete_multi(keys)
  end
end
