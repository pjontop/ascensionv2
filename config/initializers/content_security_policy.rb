# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline
    policy.connect_src :self, :https
    policy.frame_ancestors :none

    # Allow Vite HMR in development
    if Rails.env.development?
      policy.script_src(*policy.script_src, :unsafe_eval, "http://#{ViteRuby.config.host_with_port}")
      policy.connect_src(*policy.connect_src, "http://#{ViteRuby.config.host_with_port}", "ws://#{ViteRuby.config.host_with_port}")
    end
  end

  # Nonce for inline scripts (e.g. the auth login trampoline).
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
