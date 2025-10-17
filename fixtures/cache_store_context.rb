# frozen_string_literal: true

require "active_support/cache"
require "async_redis_cache_store"
require "sus/fixtures/async"
require "securerandom"

CacheStoreContext = Sus::Shared("cache store context") do
  include Sus::Fixtures::Async::ReactorContext

  let(:url) { ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") }
  let(:store) { @store = ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url, pool: { size: 5 }) }

  # Helper for generating unique test keys
  let(:test_key) { "test:#{SecureRandom.hex(4)}" }

  # Helper for generating multiple keys
  def test_keys(count)
    Array.new(count) { "test:#{SecureRandom.hex(4)}" }
  end

  after do
    # Cleanup any test keys if needed
    # Note: Using unique keys per test usually makes this unnecessary
  end
end
