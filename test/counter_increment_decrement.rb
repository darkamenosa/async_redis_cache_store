# frozen_string_literal: true

require "sus/fixtures/async"
require "active_support/cache"
require "securerandom"
require "async_redis_cache_store"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include Sus::Fixtures::Async::ReactorContext

  let(:url) { ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") }
  let(:store) { ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url, pool: { size: 5 }) }

  it "increments and decrements a counter" do
    key = "sus:ctr:#{SecureRandom.hex(3)}"
    expect(store.write(key, 0, raw: true, expires_in: 10)).to be == true
    expect(store.increment(key, 2)).to be == 2
    expect(store.decrement(key, 1)).to be == 1
  ensure
    store.delete(key)
  end
end

