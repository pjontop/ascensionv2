Rails.application.config.middleware.use OmniAuth::Builder do
  hackclub_creds = Rails.application.credentials[:hackclub] || {}

  provider :openid_connect,
    name: :hackclub,
    scope: %i[openid profile email slack_id verification_status],
    response_type: :code,
    response_mode: :query,
    discovery: true,
    issuer: "https://auth.hackclub.com",
    uid_field: "sub",
    client_options: {
      identifier: hackclub_creds[:client_id] || ENV["HACKCLUB_CLIENT_ID"],
      secret: hackclub_creds[:client_secret] || ENV["HACKCLUB_CLIENT_SECRET"],
      redirect_uri: hackclub_creds[:redirect_uri] || ENV["HACKCLUB_REDIRECT_URI"]
    }
end

OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.path_prefix = "/auth"