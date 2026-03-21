# frozen_string_literal: true

# sonnnnnn
class SyncRsvpToLoopsJob < ApplicationJob
  queue_as :default

  def perform(rsvp_id)

    return unless loops_sync_enabled?
    return if Rails.application.credentials.dig(:loops, :api_key).blank?

    rsvp = Rsvp.find_by(id: rsvp_id)
    return if rsvp.blank?
    unless loops_eligible_email?(rsvp.email)
      Rails.logger.info("Skipping Loops sync for RSVP #{rsvp_id}: invalid email #{rsvp.email.inspect} (#{EmailAddress.error(rsvp.email)})")
      return
    end

    Rails.logger.info("Sending RSVP #{rsvp_id} to Loops for #{rsvp.email.inspect}")

    LoopsSdk::Events.send(
      event_name: event_name,
      email: rsvp.email,
      event_properties: event_properties(rsvp),
    )

    # PostHog: Track successful Loops sync
    PostHog.capture(
      distinct_id: rsvp.email,
      event: "loops_sync_completed",
      properties: {rsvp_id: rsvp_id}
    )
  rescue LoopsSdk::RateLimitError => e
    Rails.logger.error("Loops Rate Limit WHILE Rsvp #{rsvp_id}: #{e.message}")
    # PostHog: Track Loops sync failure
    PostHog.capture(
      distinct_id: rsvp&.email || "anonymous",
      event: "loops_sync_failed",
      properties: {rsvp_id: rsvp_id, error_type: "rate_limit", error_message: e.message}
    )
  rescue LoopsSdk::APIError => e
    message = e.respond_to?(:json) ? e.json&.fetch("message", e.message) : e.message
    Rails.logger.error("Loops API Error WHILE Rsvp #{rsvp_id}: #{message}")
    # PostHog: Track Loops sync failure
    PostHog.capture(
      distinct_id: rsvp&.email || "anonymous",
      event: "loops_sync_failed",
      properties: {rsvp_id: rsvp_id, error_type: "api_error", error_message: message}
    )
  rescue StandardError => e
    Rails.logger.error("Unknown Loops Error for RSVP #{rsvp_id}: #{e.class} - #{e.message}")
  end

  private
# don't sync loops in a test environment and allow the ability to disable
  def loops_sync_enabled?
    return false if Rails.env.test?

    credentials_value = Rails.application.credentials.dig(:loops, :sync_enabled)
    return true if credentials_value.nil?

    ActiveModel::Type::Boolean.new.cast(credentials_value)
  end

  def event_name
    Rails.application.credentials.dig(:loops, :signup_event_name).presence || "RSVP"
  end

  def loops_eligible_email?(email)
    EmailAddress.valid?(email)
  rescue StandardError => e
    Rails.logger.error("Email validation failed for Loops sync: #{e.class} - #{e.message}")
    false
  end

  def event_properties(rsvp)
    {
      submittedAt: rsvp.submitted_at&.iso8601,
      ipAddress: rsvp.ip_address
    }.compact
  end
end
