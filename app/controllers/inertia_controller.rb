# frozen_string_literal: true

class InertiaController < ApplicationController
  # NOTE: default_render only infers component name; it never auto-passes ivars as props.
  inertia_config default_render: true

  inertia_share posthog: lambda {
    {
      key: Rails.application.credentials.dig(:posthog, :project_token),
      host: Rails.application.credentials.dig(:posthog, :host)
    }
  }

  inertia_share auth: lambda {
    {
      user: current_user&.then do |user|
        {
          id: user.id,
          name: user.name,
          email: user.email,
          verified: !!user.email_verified,
          created_at: user.created_at,
          updated_at: user.updated_at
        }
      end,
      session: current_user ? {id: request.session.id.to_s} : nil
    }
  }
end
