# frozen_string_literal: true

require "sus/fixtures/async"
require "active_support/cache"
require "securerandom"
require "async_redis_cache_store"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include Sus::Fixtures::Async::ReactorContext

  let(:url) { ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") }
  let(:store) { ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url, pool: { size: 5 }) }

  it "deletes keys matching a glob pattern" do
    base = "sus:scan:\#{SecureRandom.hex(3)}"
    keys = %W[\#{base}:a \#{base}:b \#{base}:c]
    keys.each { |k| store.write(k, "x", expires_in: 30) }

    expect(store.delete_matched("\#{base}:*")).to be_nil # API returns nil on success

    keys.each { |k| expect(store.read(k)).to be_nil }
  end
end
