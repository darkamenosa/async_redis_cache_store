# frozen_string_literal: true

require_relative "lib/async_redis_cache_store/version"

Gem::Specification.new do |spec|
  spec.name          = "async_redis_cache_store"
  spec.version       = AsyncRedisCacheStore::VERSION
  spec.authors       = [ "Contributors" ]
  spec.email         = [ "" ]

  spec.summary       = "Async Redis-backed ActiveSupport::Cache store using Falcon/Async fibers."
  spec.description   = "Fiber-friendly, high-throughput Redis cache store for Rails/ActiveSupport using async-redis. Supports single, distributed and cluster modes with a bounded connection pool."
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
  spec.add_dependency "activesupport", ">= 7.0"
  spec.add_dependency "async-redis", ">= 0.13.0"
  spec.add_dependency "async", ">= 2.0"

  # Development dependencies

  spec.metadata["rubygems_mfa_required"] = "true"
end
