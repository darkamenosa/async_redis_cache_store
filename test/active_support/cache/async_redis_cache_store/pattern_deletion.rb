# frozen_string_literal: true

require "cache_store_context"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include_context CacheStoreContext

  it "deletes keys matching a glob pattern" do
    base = "pattern:#{SecureRandom.hex(3)}"
    keys = %W[#{base}:a #{base}:b #{base}:c]
    keys.each { |k| store.write(k, "x", expires_in: 30) }

    expect(store.delete_matched("#{base}:*")).to be_nil # API returns nil on success

    keys.each { |k| expect(store.read(k)).to be_nil }
  end
end
