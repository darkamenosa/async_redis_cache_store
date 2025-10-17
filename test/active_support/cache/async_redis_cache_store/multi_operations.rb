# frozen_string_literal: true

require "cache_store_context"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include_context CacheStoreContext

  it "writes and reads multiple keys" do
    keys = test_keys(5)
    values = keys.map { |k| [ k, "value-#{k.split(":").last}" ] }.to_h

    store.write_multi(values, expires_in: 10)

    result = store.read_multi(*keys)
    expect(result.size).to be == keys.size
    keys.each do |k|
      expect(result[k]).to be =~ /value-/
    end
  ensure
    store.delete_multi(keys)
  end

  it "uses fetch_multi for multiple keys" do
    keys = test_keys(3)

    # First call should execute block for all missing keys
    result = store.fetch_multi(*keys, expires_in: 10) do |key|
      "computed-#{key.split(":").last}"
    end

    expect(result.size).to be == keys.size
    keys.each do |k|
      expect(result[k]).to be =~ /computed-/
    end

    # Verify values were cached
    cached = store.read_multi(*keys)
    expect(cached.size).to be == keys.size
  ensure
    store.delete_multi(keys)
  end

  it "handles empty array in read_multi" do
    result = store.read_multi()
    expect(result).to be == {}
  end

  it "handles empty hash in write_multi" do
    # Should not raise, just return early
    store.write_multi({})
    # No error means success
  end

  it "handles empty array in delete_multi" do
    # Should return early without error
    result = store.send(:delete_multi_entries, [])
    expect(result).to be_nil
  end

  it "handles read_multi with some non-existent keys" do
    key1 = test_key
    key2 = "nonexistent:#{SecureRandom.hex(8)}"

    store.write(key1, "exists", expires_in: 10)

    result = store.read_multi(key1, key2)

    expect(result[key1]).to be == "exists"
    expect(result.key?(key2)).to be == false
  ensure
    store.delete(key1)
  end
end
