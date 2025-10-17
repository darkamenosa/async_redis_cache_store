# frozen_string_literal: true

require "cache_store_context"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include_context CacheStoreContext

  it "handles nil value writes and reads" do
    key = test_key

    store.write(key, nil, expires_in: 10)
    expect(store.read(key)).to be_nil
  ensure
    store.delete(key)
  end

  it "handles reading non-existent keys" do
    key = "nonexistent:#{SecureRandom.hex(8)}"
    expect(store.read(key)).to be_nil
  end

  it "handles delete on non-existent key" do
    key = "nonexistent:delete:#{SecureRandom.hex(8)}"
    # Should return false since key doesn't exist
    result = store.delete(key)
    expect(result).to be == false
  end
end
