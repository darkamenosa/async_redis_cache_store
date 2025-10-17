# frozen_string_literal: true

require "covered/sus"

# Normalize COVERAGE to valid Covered reporter class names.
# Accept friendly aliases: summary, markdown, partial, full, quiet.
if ENV.key?("COVERAGE")
  mapped = ENV["COVERAGE"].split(",").map do |name|
    case name.strip.downcase
    when "summary", "brief", "brief_summary" then "BriefSummary"
    when "markdown", "md", "markdown_summary" then "MarkdownSummary"
    when "partial", "partial_summary" then "PartialSummary"
    when "full", "full_summary" then "FullSummary"
    when "quiet" then "Quiet"
    else name
    end
  end
  ENV["COVERAGE"] = mapped.join(",")
else
  ENV["COVERAGE"] = "BriefSummary"
end

include Covered::Sus
