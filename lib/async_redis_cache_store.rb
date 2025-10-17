# frozen_string_literal: true

require_relative "async_redis_cache_store/version"

# Public entrypoint: load the cache store implementation.
require "active_support/cache"
require "active_support/notifications"
require "active_support/isolated_execution_state"
require "active_support/core_ext/numeric/time"
require_relative "active_support/cache/async_redis_cache_store"

module AsyncRedisCacheStore
end

module AsyncRedisCacheStore
  class Error < StandardError; end
  # Your code goes here...
end
