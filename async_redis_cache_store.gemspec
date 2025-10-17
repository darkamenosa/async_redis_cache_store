# frozen_string_literal: true

require_relative "lib/async_redis_cache_store/version"

Gem::Specification.new do |spec|
  spec.name          = "async_redis_cache_store"
  spec.version       = AsyncRedisCacheStore::VERSION
  spec.authors       = [ "darkamenosa" ]
  spec.email         = [ "hxtxmu@gmail.com" ]

  spec.summary       = "Fiber-friendly, high-throughput Redis cache store for Rails/ActiveSupport built on async-redis."
  spec.description   = "Async Redis cache store for Rails/ActiveSupport using async-redis. Supports single, distributed (sharded), and cluster modes with bounded connection pooling. Drop-in replacement for RedisCacheStore with fiber-based concurrency optimized for Falcon/Async servers."
  spec.homepage      = "https://github.com/darkamenosa/async_redis_cache_store"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.1.0"

  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    gemspec = File.basename(__FILE__)
    ls.readlines("\x0", chomp: true).reject do |f|
      f == gemspec || f.start_with?(*%w[bin/ Gemfile .gitignore test/ .github/ .rubocop.yml])
    end
  end

  spec.require_paths = [ "lib" ]

  # Runtime dependencies
  spec.add_dependency "activesupport", ">= 6.0"
  spec.add_dependency "async-redis", ">= 0.13.0"
  spec.add_dependency "async", ">= 2.0"

  # Development dependencies

  # Metadata
  spec.metadata["homepage_uri"]          = spec.homepage
  spec.metadata["source_code_uri"]       = "https://github.com/darkamenosa/async_redis_cache_store"
  spec.metadata["bug_tracker_uri"]       = "https://github.com/darkamenosa/async_redis_cache_store/issues"
  spec.metadata["documentation_uri"]     = "https://github.com/darkamenosa/async_redis_cache_store#readme"
  spec.metadata["rubygems_mfa_required"] = "true"
end
