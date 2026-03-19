# frozen_string_literal: true

class InertiaController < ApplicationController
  inertia_config default_render: true

  inertia_share posthog: lambda {
    {
      key: Rails.application.credentials.dig(:posthog, :project_token),
      host: Rails.application.credentials.dig(:posthog, :host)
    }
  }
end
