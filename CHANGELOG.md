# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-01-18

### Added
- Initial release of AsyncRedisCacheStore
- Single Redis mode with connection pooling
- Distributed (sharded) mode with consistent hashing
- Redis Cluster mode support
- Hash tag routing for distributed mode (`{tag}` syntax)
- Full ActiveSupport::Cache::Store API compatibility
- Fiber-based concurrency using async-redis
- Bounded connection pool (configurable via `:pool` option)
- Multi-key operations: `read_multi`, `write_multi`, `delete_multi`, `fetch_multi`
- Counter operations: `increment`, `decrement`
- Pattern deletion: `delete_matched` with SCAN support
- Cache versioning support
- Namespace isolation
- TTL and expiration management
- Race condition TTL support
- Configurable error handling and retry logic
- Comprehensive test suite with 85%+ coverage
- Support for Ruby >= 3.1.0
- Support for Rails/ActiveSupport >= 6.0

[Unreleased]: https://github.com/darkamenosa/async_redis_cache_store/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/darkamenosa/async_redis_cache_store/releases/tag/v0.1.0
