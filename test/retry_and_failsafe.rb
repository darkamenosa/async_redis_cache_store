# frozen_string_literal: true

require "sus/fixtures/async"
require "async"
require "async/clock"
require "active_support/cache"
require "async_redis_cache_store"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include Sus::Fixtures::Async::ReactorContext

  let(:url) { ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") }
  let(:store) { ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url, pool: { size: 5 }, reconnect_attempts: 2) }

  it "retries once on transient error via call_redis" do
    hits = 0
    result = store.send(:call_redis) do |_c|
      hits += 1
      raise IOError if hits == 1
      :ok
    end
    expect(result).to be == :ok
  end

  it "failsafe returns default on error" do
    value = store.send(:failsafe, :read_entry, returning: :default) do
      raise IOError, "boom"
    end
    expect(value).to be == :default
  end
end

