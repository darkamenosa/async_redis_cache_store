# frozen_string_literal: true

# This file customizes Covered's behavior. It is loaded by Covered::Config.

# Define a simple threshold reporter that fails the build if coverage is below a minimum.
module ::Covered
  class Threshold
    def initialize(minimum = nil)
      @minimum = minimum
    end

    def minimum
      # Allow overriding via environment variables, default to value passed to constructor:
      env = ENV["COVERAGE_MIN"] || ENV["COVERAGE_MINIMUM"]
      value = env ? env.to_f : @minimum
      return nil if value.nil?
      # Accept percentages (e.g., 80) or ratios (e.g., 0.8):
      (value && value > 1) ? (value / 100.0) : value
    end

    def call(wrapper, output = $stdout)
      statistics = ::Covered::Statistics.new
      wrapper.each { |coverage| statistics << coverage }

      min = minimum
      return unless min && min > 0

      # Raises ::Covered::CoverageError if below threshold:
      statistics.validate!(min)
    end
  end
end

# This module is evaluated in the context of a configuration module that is
# prepended to Covered::Config, so we can override methods like make_policy.
def make_policy(policy)
  super(policy)

  # Append our threshold reporter so it runs after any summaries.
  policy.reports << ::Covered::Threshold.new
end
