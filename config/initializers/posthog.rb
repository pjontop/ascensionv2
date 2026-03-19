# frozen_string_literal: true

# PostHog configuration with posthog-rails auto-instrumentation
#
# The posthog-rails gem provides:
# - Automatic exception capture for unhandled controller errors
# - ActiveJob instrumentation for background job failures
# - Rails.error integration for rescued exceptions
posthog_key = Rails.application.credentials.dig(:posthog, :project_token)
posthog_host = Rails.application.credentials.dig(:posthog, :host)

if posthog_key.present?
  PostHog.init do |config|
    config.api_key = posthog_key
    config.host = posthog_host
  end

  PostHog::Rails.configure do |config|
    # Auto-capture unhandled exceptions in controllers
    config.auto_capture_exceptions = true

    # Also capture exceptions that Rails rescues (e.g. ActiveRecord::RecordNotFound)
    config.report_rescued_exceptions = true

    # Auto-instrument ActiveJob failures
    config.auto_instrument_active_job = true
  end
end
