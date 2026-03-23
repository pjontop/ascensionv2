Rails.application.config.middleware.use OmniAuth::Builder do
  hackclub_creds = Rails.application.credentials[:hackclub] || {}
  configured_redirect_uri = hackclub_creds[:redirect_uri] || ENV["HACKCLUB_REDIRECT_URI"]

  provider :openid_connect,
    name: :hackclub,
    scope: %i[openid profile email slack_id verification_status],
    response_type: :code,
    response_mode: :query,
    discovery: true,
    issuer: "https://auth.hackclub.com",
    uid_field: "sub",
    setup: lambda { |env|
      strategy = env["omniauth.strategy"]
      request = Rack::Request.new(env)

      redirect_uri = if Rails.env.development?
                       "#{request.base_url}/auth/hackclub/callback"
                     else
                       configured_redirect_uri
                     end

      strategy.options.client_options.redirect_uri = redirect_uri if redirect_uri.present?
    },
    client_options: {
      identifier: hackclub_creds[:client_id] || ENV["HACKCLUB_CLIENT_ID"],
      secret: hackclub_creds[:client_secret] || ENV["HACKCLUB_CLIENT_SECRET"]
    }
end

OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.path_prefix = "/auth"