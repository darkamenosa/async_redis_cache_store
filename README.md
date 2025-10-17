# AsyncRedisCacheStore

Fiber-friendly, high-throughput Redis cache store for Rails/ActiveSupport built on [async-redis](https://github.com/socketry/async-redis).

## Features

- **Single, distributed (sharded), and cluster modes** - Full compatibility with Redis deployment patterns
- **Bounded connection pool** - Configurable via `:pool` option (parity with RedisCacheStore). Defaults to `{ size: 5 }`
- **Async-first design** - Works optimally with [Falcon](https://github.com/socketry/falcon)/Async servers
- **Thread-safe** - Safe to use in thread-based servers (Puma, Unicorn, etc.)
- **Drop-in replacement** - Compatible with ActiveSupport::Cache::Store API

## Requirements

- Ruby >= 3.1.0
- Rails/ActiveSupport >= 6.0
- Running Redis server (redis gem is NOT required)

## Installation

Add this line to your application's Gemfile:

```ruby
gem "async_redis_cache_store"
```

And then execute:

```bash
bundle install
```

## Configuration

### Basic Setup (Single Redis)

```ruby
# config/environments/production.rb
config.cache_store = :async_redis_cache_store, {
  url: ENV["REDIS_URL"]
}
```

### With Connection Pool

```ruby
config.cache_store = :async_redis_cache_store, {
  url: ENV["REDIS_URL"],
  pool: { size: 32 }  # Default: 5
}
```

### Distributed Mode (Sharding)

```ruby
config.cache_store = :async_redis_cache_store, {
  url: [
    ENV["REDIS_URL_1"],
    ENV["REDIS_URL_2"],
    ENV["REDIS_URL_3"]
  ],
  pool: { size: 10 }
}
```

### Cluster Mode

```ruby
config.cache_store = :async_redis_cache_store, {
  url: [
    "redis://node1:6379",
    "redis://node2:6379",
    "redis://node3:6379"
  ],
  cluster: true,
  pool: { size: 10 }
}
```

### Additional Options

```ruby
config.cache_store = :async_redis_cache_store, {
  url: ENV["REDIS_URL"],

  # Connection pool
  pool: { size: 5 },                    # Default: 5, set to false for unbounded

  # Timeouts
  connect_timeout: 5,                   # seconds
  read_timeout: 1,                      # seconds
  write_timeout: 1,                     # seconds

  # Retry behavior
  reconnect_attempts: 1,                # Default: 1

  # Error handling
  error_handler: ->(method:, returning:, exception:) {
    Rails.logger.warn("Cache error: #{exception}")
  },

  # Standard ActiveSupport::Cache options
  namespace: "myapp",
  expires_in: 1.hour,
  race_condition_ttl: 5.seconds
}
```

## Usage

Use standard ActiveSupport::Cache::Store API:

```ruby
# Basic operations
Rails.cache.read("key")
Rails.cache.write("key", "value", expires_in: 1.hour)
Rails.cache.fetch("key") { expensive_operation }
Rails.cache.delete("key")

# Multi-key operations
Rails.cache.read_multi("key1", "key2", "key3")
Rails.cache.write_multi({ "key1" => "val1", "key2" => "val2" })
Rails.cache.delete_multi(["key1", "key2"])

# Counters
Rails.cache.increment("counter", 1)
Rails.cache.decrement("counter", 1)

# Pattern matching
Rails.cache.delete_matched("users:*")
```

## Development

After checking out the repo, run `bin/setup` to install dependencies.

### Running Tests

This project uses [Sus](https://github.com/socketry/sus) for testing (following async-redis patterns).

**Prerequisites:**
- Running Redis server on `localhost:6379` (or set `REDIS_URL`)

**Run all tests:**

```bash
# Via bake (includes coverage)
REDIS_URL=redis://127.0.0.1:6379/0 bundle exec bake test

# Or directly with sus
REDIS_URL=redis://127.0.0.1:6379/0 bundle exec sus
```

**Run specific test file:**

```bash
REDIS_URL=redis://127.0.0.1:6379/0 bundle exec sus test/active_support/cache/async_redis_cache_store/counters.rb
```

### Test Coverage

Coverage is enabled via `config/sus.rb` using the [covered](https://github.com/socketry/covered) gem.

**Coverage options:**
```bash
# Default summary
REDIS_URL=redis://127.0.0.1:6379/0 bundle exec bake test

# Markdown summary
COVERAGE=markdown REDIS_URL=redis://127.0.0.1:6379/0 bundle exec bake test

# Partial summary (focused on touched files)
COVERAGE=partial REDIS_URL=redis://127.0.0.1:6379/0 bundle exec bake test
```

### Code Quality

```bash
# Run RuboCop
bundle exec rubocop

# Auto-fix issues
bundle exec rubocop -a
```

### Interactive Console

```bash
bin/console
```

This opens an IRB session with the gem loaded for experimentation.

### Test Structure

Tests are organized by feature/functionality:

```
test/
└── active_support/cache/async_redis_cache_store/
    ├── basic_operations.rb      # read, write, delete, fetch, exist?
    ├── multi_operations.rb      # read_multi, write_multi, etc.
    ├── counters.rb              # increment, decrement
    ├── expiration.rb            # TTL, NX, race_condition_ttl
    ├── versioning.rb            # cache versioning
    ├── namespaces.rb            # namespace isolation
    ├── distributed.rb           # distributed mode, hash tags
    ├── configuration.rb         # pool configs, timeouts
    ├── error_handling.rb        # failsafe, retry, error_handler
    ├── pattern_deletion.rb      # delete_matched
    └── edge_cases.rb            # nil, non-existent keys

fixtures/
└── cache_store_context.rb       # Shared test context
```

## Architecture

- **lib/active_support/cache/async_redis_cache_store.rb** - Main cache store implementation
- **lib/async_redis_cache_store/async_distributed.rb** - Distributed (sharding) client with consistent hashing
- Built on [async-redis](https://github.com/socketry/async-redis) for fiber-based concurrency
- Connection pooling via [async-pool](https://github.com/socketry/async-pool)

## Performance

AsyncRedisCacheStore is designed for high-throughput scenarios:

- **Fiber-based concurrency** - Thousands of concurrent operations without thread overhead
- **Connection pooling** - Bounded resources, configurable limits
- **Pipeline support** - Batch operations for multi-key writes
- **Optimized for Falcon** - Native async/await support

## Differences from RedisCacheStore

| Feature | RedisCacheStore | AsyncRedisCacheStore |
|---------|----------------|---------------------|
| Concurrency | Thread-based (connection_pool) | Fiber-based (async-pool) |
| Redis gem | Requires `redis` gem | Uses `async-redis` |
| Pipelining | Limited | Native support |
| Async servers | Blocks fibers | Non-blocking |
| Thread safety | ✅ Yes | ✅ Yes |
| API compatibility | Standard | ✅ Standard (drop-in) |

## Contributing

 Bug reports and pull requests are welcome on GitHub at https://github.com/darkamenosa/async_redis_cache_store

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
