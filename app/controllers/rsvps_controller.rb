# frozen_string_literal: true

require "cgi"
require "json"
require "net/http"

class RsvpsController < InertiaController
  # rate limit, by ip, otherwise loops will do it for us
  MAX_RSVPS_PER_WINDOW = 5
  RSVP_RATE_LIMIT_WINDOW = 10.minutes
  GEOLOCATION_CACHE_TTL = 6.hours

  before_action :enforce_rsvp_rate_limit!, only: :create

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

    cache_key = "rsvp:geolocation:#{ip}"
    cached_data = Rails.cache.read(cache_key)
    return cached_data if cached_data.present?

    data = fetch_geolocation_data(ip)
    Rails.cache.write(cache_key, data, expires_in: GEOLOCATION_CACHE_TTL) if data.present?
    data
  rescue StandardError
    {}
  end

  def fetch_geolocation_data(ip)
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

  def enforce_rsvp_rate_limit!
    cache_key = "rsvp:rate-limit:#{request.remote_ip}"
    attempts = increment_counter(cache_key, expires_in: RSVP_RATE_LIMIT_WINDOW)
    return if attempts <= MAX_RSVPS_PER_WINDOW

    redirect_back_or_to(
      landing_path,
      alert: "Too many RSVP attempts. Please try again later.",
      inertia: {errors: {email: ["Too many submissions from your network. Please wait and try again."]}}
    )
  end

  def increment_counter(key, expires_in:)
    next_value = Rails.cache.read(key).to_i + 1
    Rails.cache.write(key, next_value, expires_in: expires_in)
    next_value
  rescue StandardError
    1
  end
end
