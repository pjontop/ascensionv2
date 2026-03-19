# frozen_string_literal: true

require "cgi"
require "json"
require "net/http"

class RsvpsController < InertiaController
  def create
    posthog_enabled = Rails.application.credentials.dig(:posthog, :project_token).present?

    rsvp = Rsvp.new(
      email: rsvp_params[:email],
      submitted_at: Time.current,
      ip_address: request.remote_ip,
      user_agent: request.user_agent,
      geolocation_data: geolocation_data,
    )

    if rsvp.save
      SyncRsvpToLoopsJob.perform_later(rsvp.id)

      # PostHog: Identify and track successful RSVP submission
      if posthog_enabled
        PostHog.identify(
          distinct_id: rsvp.email,
          properties: {email: rsvp.email}
        )
        PostHog.capture(
          distinct_id: rsvp.email,
          event: "rsvp_submitted",
          properties: {ip_address: rsvp.ip_address}
        )
      end

      redirect_to landing_path, notice: "We got you! Cya there!"
    else
      # PostHog: Track failed RSVP submission
      if posthog_enabled
        PostHog.capture(
          distinct_id: rsvp_params[:email].presence || "anonymous",
          event: "rsvp_failed",
          properties: {errors: rsvp.errors.to_hash(true)}
        )
      end

      redirect_back_or_to landing_path, inertia: {errors: rsvp.errors.to_hash(true)}
    end
  end

  private

  def rsvp_params
    params.permit(:email)
  end

  def geolocation_data
    ip = request.remote_ip
    return {} if ip.blank?

    url = URI("https://ip.hackclub.com/ip/#{CGI.escape(ip)}")
    response = Net::HTTP.start(url.host, url.port, use_ssl: true, open_timeout: 2, read_timeout: 2) do |http|
      http.get(url.request_uri)
    end

    return {} unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)
  rescue JSON::ParserError, SocketError, Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
    {}
  end
end
