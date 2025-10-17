# frozen_string_literal: true

require "sus/fixtures/async"
require "active_support/cache"
require "securerandom"
require "async_redis_cache_store"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include Sus::Fixtures::Async::ReactorContext

  let(:url) { ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") }

  it "writes and reads a value" do
    store = ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url, pool: { size: 5 })

    key = "sus:test:#{SecureRandom.hex(4)}"
    begin
      store.write(key, "v", expires_in: 10)
      expect(store.read(key)).to be == "v"
    rescue => e
      warn "write/read failed: #{e.class}: #{e.message}\n\t#{e.backtrace&.first}"
      raise
    ensure
      begin
        store.delete(key)
      rescue => e
        warn "cleanup failed: #{e.class}: #{e.message}"
      end
    end
  end
end
