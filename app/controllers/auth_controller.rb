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
      response.set_header("X-Inertia-Location", login_url)
      head :conflict
      return
    end

    render inline: <<~ERB, layout: false
      <!doctype html>
      <html>
        <head>
          <meta charset="utf-8" />
          <meta name="viewport" content="width=device-width, initial-scale=1" />
          <title>Redirecting to Hack Club Auth</title>
        </head>
        <body>
          <form id="auth-start-form" method="post" action="/auth/hackclub">
            <input type="hidden" name="authenticity_token" value="<%= form_authenticity_token %>" />
          </form>
          <noscript>
            <p>JavaScript is required to continue. Please click below.</p>
            <button form="auth-start-form" type="submit">Continue</button>
          </noscript>
          <script nonce="<%= content_security_policy_nonce %>">
            document.getElementById('auth-start-form').submit()
          </script>
        </body>
      </html>
    ERB
  end

  def callback
    auth = request.env["omniauth.auth"]

    user = User.find_or_initialize_by(uid: auth["uid"])
    user.update!(
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
    redirect_to landing_path, notice: "Logged in as #{user.name}"
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