# frozen_string_literal: true

require "cache_store_context"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include_context CacheStoreContext

  it "supports cache versioning" do
    expect(ActiveSupport::Cache::AsyncRedisCacheStore.supports_cache_versioning?).to be == true
  end

  it "returns nil for version mismatched entries" do
    key = test_key

    # Write with version 1
    store.write(key, "value_v1", expires_in: 10, version: 1)
    expect(store.read(key, version: 1)).to be == "value_v1"

    # Reading with different version should return nil
    expect(store.read(key, version: 2)).to be_nil
  ensure
    store.delete(key)
  end
end
