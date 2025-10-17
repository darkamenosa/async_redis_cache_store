# frozen_string_literal: true

require "cache_store_context"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include_context CacheStoreContext

  it "writes and reads a value" do
    key = test_key
    store.write(key, "value", expires_in: 10)
    expect(store.read(key)).to be == "value"
  ensure
    store.delete(key)
  end

  it "writes, reads and deletes a value" do
    key = test_key
    expect(store.write(key, "value", expires_in: 10)).to be == true
    expect(store.read(key)).to be == "value"
    expect(store.delete(key)).to be == true
    expect(store.read(key)).to be_nil
  end

  it "checks if key exists" do
    key = test_key
    expect(store.exist?(key)).to be == false

    store.write(key, "value", expires_in: 10)
    expect(store.exist?(key)).to be == true

    store.delete(key)
    expect(store.exist?(key)).to be == false
  end

  it "uses fetch to read or write a value" do
    key = test_key
    call_count = 0

    # First fetch should execute block and cache the result
    result1 = store.fetch(key, expires_in: 10) do
      call_count += 1
      "computed_value"
    end

    expect(result1).to be == "computed_value"
    expect(call_count).to be == 1

    # Second fetch should return cached value without executing block
    result2 = store.fetch(key, expires_in: 10) do
      call_count += 1
      "should_not_execute"
    end

    expect(result2).to be == "computed_value"
    expect(call_count).to be == 1
  ensure
    store.delete(key)
  end

  it "uses fetch with force: true to recompute" do
    key = test_key
    store.write(key, "old_value", expires_in: 10)

    result = store.fetch(key, expires_in: 10, force: true) do
      "new_value"
    end

    expect(result).to be == "new_value"
    expect(store.read(key)).to be == "new_value"
  ensure
    store.delete(key)
  end

  it "handles inspect method" do
    store_inspect = store.inspect
    expect(store_inspect).to be =~ /AsyncRedisCacheStore/
    expect(store_inspect).to be =~ /options=/
  end

  it "calls stats and returns info per node" do
    info = store.stats
    # For single node, expect an Array with one Hash-like info String or Hash depending on protocol.
    expect(info).to respond_to(:each)
  end

  it "clears cache when no namespace is specified" do
    key = test_key
    store.write(key, "value", expires_in: 10)
    store.clear
    expect(store.read(key)).to be_nil
  end
end
