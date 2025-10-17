# frozen_string_literal: true

require "sus/fixtures/async"
require "active_support/cache"
require "securerandom"
require "async_redis_cache_store"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include Sus::Fixtures::Async::ReactorContext

  let(:url) { ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") }
  let(:store) { ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url, pool: { size: 5 }) }

  it "writes, reads and deletes a value" do
    key = "sus:basic:#{SecureRandom.hex(4)}"
    expect(store.write(key, "value", expires_in: 10)).to be == true
    expect(store.read(key)).to be == "value"
    expect(store.delete(key)).to be == true
    expect(store.read(key)).to be_nil
  end
end
