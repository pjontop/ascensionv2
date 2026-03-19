# frozen_string_literal: true

# PostHog configuration with posthog-rails auto-instrumentation
#
# The posthog-rails gem provides:
# - Automatic exception capture for unhandled controller errors
# - ActiveJob instrumentation for background job failures
# - Rails.error integration for rescued exceptions
PostHog.init do |config|
  config.api_key = ENV.fetch("POSTHOG_PROJECT_TOKEN", nil)
  config.host = ENV.fetch("POSTHOG_HOST", nil)
end

PostHog::Rails.configure do |config|
  # Auto-capture unhandled exceptions in controllers
  config.auto_capture_exceptions = true

  # Also capture exceptions that Rails rescues (e.g. ActiveRecord::RecordNotFound)
  config.report_rescued_exceptions = true

  # Auto-instrument ActiveJob failures
  config.auto_instrument_active_job = true
end
