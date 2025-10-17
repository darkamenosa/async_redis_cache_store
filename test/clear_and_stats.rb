# frozen_string_literal: true

require "sus/fixtures/async"
require "active_support/cache"
require "securerandom"
require "async_redis_cache_store"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include Sus::Fixtures::Async::ReactorContext

  let(:url) { ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") }
  let(:store) { ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url, pool: { size: 5 }) }

  it "calls stats and returns info per node" do
    info = store.stats
    # For single node, expect an Array with one Hash-like info String or Hash depending on protocol.
    expect(info).to respond_to(:each)
  end

  it "clear removes keys in current DB when no namespace" do
    key = "sus:clear:\#{SecureRandom.hex(3)}"
    store.write(key, "x", expires_in: 10)
    store.clear
    expect(store.read(key)).to be_nil
  end
end
