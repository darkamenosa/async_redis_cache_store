# frozen_string_literal: true

require "sus/fixtures/async"
require "active_support/cache"
require "securerandom"
require "async_redis_cache_store"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include Sus::Fixtures::Async::ReactorContext

  let(:url) { ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") }
  let(:store) { ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url, pool: { size: 5 }) }

  it "respects NX and PX TTL" do
    key = "sus:nx:#{SecureRandom.hex(3)}"
    expect(store.write(key, "first", expires_in: 0.2, unless_exist: true)).to be == true
    # second write with NX should be ignored and return false boolean:
    expect(store.write(key, "second", expires_in: 0.2, unless_exist: true)).to be == false
    expect(store.read(key)).to be == "first"

    Async::Task.current.sleep(0.25)
    expect(store.read(key)).to be_nil
  ensure
    store.delete(key)
  end
end
