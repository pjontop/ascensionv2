# frozen_string_literal: true

class AuthController < ApplicationController
  skip_forgery_protection only: [:callback]

  def login
    track_event(
      "auth_login_started",
      provider: "hackclub",
      path: request.path,
      user_agent: request.user_agent
    )

    if request.headers["X-Inertia"] == "true"
      response.set_header("X-Inertia-Location", "#{request.base_url}/auth/hackclub")
      head :conflict
    else
      redirect_to "/auth/hackclub"
    end
  end

  def callback
    auth = request.env["omniauth.auth"]

    user = User.find_or_create_by(uid: auth["uid"]) do |u|
      u.name = auth.dig("info", "name")
      u.email = auth.dig("info", "email")
      u.slack_id = auth.dig("extra", "raw_info", "slack_id")
      u.email_verified = auth.dig("extra", "raw_info", "email_verified")
      u.verification_status = auth.dig("extra", "raw_info", "verification_status")
      u.ysws_eligible = auth.dig("extra", "raw_info", "ysws_eligible")
    end

    user.update(
      name: auth.dig("info", "name"),
      email: auth.dig("info", "email"),
      slack_id: auth.dig("extra", "raw_info", "slack_id"),
      email_verified: auth.dig("extra", "raw_info", "email_verified"),
      verification_status: auth.dig("extra", "raw_info", "verification_status"),
      ysws_eligible: auth.dig("extra", "raw_info", "ysws_eligible")
    )

    PostHog.identify(
      distinct_id: user.posthog_distinct_id,
      properties: {
        email: user.email,
        name: user.name,
        slack_id: user.slack_id,
        email_verified: user.email_verified,
        verification_status: user.verification_status,
        ysws_eligible: user.ysws_eligible
      }
    )

    track_event(
      "auth_login_succeeded",
      distinct_id: user.posthog_distinct_id,
      provider: "hackclub",
      user_id: user.id,
      email_verified: user.email_verified,
      verification_status: user.verification_status,
      ysws_eligible: user.ysws_eligible
    )

    session[:user_id] = user.id
    redirect_to "/landing", notice: "Logged in as #{user.name}"
  end

  def logout
    track_event(
      "auth_logout",
      distinct_id: current_user&.posthog_distinct_id,
      provider: "hackclub",
      user_id: current_user&.id
    )

    session[:user_id] = nil
    redirect_to root_path, notice: "Logged out"
  end

  def failure
    track_event(
      "auth_login_failed",
      provider: "hackclub",
      message: params[:message],
      path: request.path
    )

    redirect_to root_path, alert: "Authentication failed: #{params[:message]}"
  end

  private

  def track_event(event, properties = {})
    PostHog.capture(
      distinct_id: properties.delete(:distinct_id) || fallback_distinct_id,
      event: event,
      properties: properties
    )
  rescue StandardError
    # Never block auth flow because analytics capture fails.
    nil
  end

  def fallback_distinct_id
    session[:user_id]&.to_s || "anon-#{request.session.id}"
  end
end