# AsyncRedisCacheStore

Fiber-friendly Redis cache store for Rails/ActiveSupport built on async-redis.

Features:
- Single, distributed (sharded), and cluster modes.
- Bounded connection pool via `:pool` (parity with RedisCacheStore). Defaults to `{ size: 5 }`.
- Works with Falcon/Async; safe in thread-based servers too.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "async_redis_cache_store"
```

Then in your Rails configuration:

```ruby
# config/environments/production.rb
config.cache_store = :async_redis_cache_store, { url: ENV["REDIS_URL"] }
# Optional: cap pool size (default 5)
# config.cache_store = :async_redis_cache_store, { url: ENV["REDIS_URL"], pool: { size: 32 } }
```

## Testing

This project follows async-redis and uses Sus for tests.

Run tests with coverage (via bake):

```bash
REDIS_URL=redis://127.0.0.1:6379/0 bundle exec bake test
```

Notes:
- You need a running Redis server (the `redis` Ruby gem is NOT required).
- CI starts `redis:7` as a service and runs Sus.

### Test Coverage

Coverage is enabled for Sus via `config/sus.rb` (requires `covered/sus`).

You’ll see a coverage summary at the end of the run. Set `COVERAGE=markdown` to emit a Markdown summary, or `COVERAGE=partial` for a focused summary of touched files (powered by the `covered` gem).


TODO: Delete this and the text below, and describe your gem

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/async_redis_cache_store`. To experiment with that code, run `bin/console` for an interactive prompt.

## Installation

TODO: Replace `UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG` with your gem name right after releasing it to RubyGems.org. Please do not do it earlier due to security reasons. Alternatively, replace this section with instructions to install your gem from git if you don't plan to release to RubyGems.org.

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install UPDATE_WITH_YOUR_GEM_NAME_IMMEDIATELY_AFTER_RELEASE_TO_RUBYGEMS_ORG
```

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/async_redis_cache_store.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
