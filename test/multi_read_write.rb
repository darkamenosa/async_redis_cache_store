# frozen_string_literal: true

require "sus/fixtures/async"
require "active_support/cache"
require "securerandom"
require "async_redis_cache_store"

describe ActiveSupport::Cache::AsyncRedisCacheStore do
  include Sus::Fixtures::Async::ReactorContext

  let(:url) { ENV.fetch("REDIS_URL", "redis://127.0.0.1:6379/0") }
  let(:store) { ActiveSupport::Cache.lookup_store(:async_redis_cache_store, url: url, pool: { size: 5 }) }

  it "writes and reads many keys" do
    keys = Array.new(5) { |i| "sus:multi:#{i}:#{SecureRandom.hex(3)}" }
    values = keys.map { |k| [k, "v-#{k.split(":")[2]}" ] }.to_h

    store.write_multi(values, expires_in: 10)

    result = store.read_multi(*keys)
    expect(result.size).to be == keys.size
    keys.each do |k|
      expect(result[k]).to be =~ /v-/
    end
  ensure
    store.delete_multi(keys)
  end
end
