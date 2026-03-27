# frozen_string_literal: true

# OpenTelemetry Logs — ships structured logs to PostHog via OTLP/HTTP.
#
# Configuration (in Rails credentials):
#
#   posthog:
#     project_token: phc_...
#     host: https://us.i.posthog.com        # optional, defaults to US endpoint
#     logs_enabled: true                    # optional, defaults to true when token present
#
# Per-environment opt-out example (config/credentials/development.yml.enc):
#   posthog:
#     logs_enabled: false
#
module OtelLogs
  POSTHOG_LOGS_ENDPOINT = "https://us.i.posthog.com/i/v1/logs"

  class << self
    def enabled?
      @enabled ||= false
    end

    def logger
      @logger
    end

    def setup!
      token = Rails.application.credentials.dig(:posthog, :project_token)
      return unless token.present?

      logs_enabled = Rails.application.credentials.dig(:posthog, :logs_enabled)
      # Default to enabled when token is present; only disable when explicitly false
      return if logs_enabled == false

      host = Rails.application.credentials.dig(:posthog, :host).presence

      endpoint = if host.nil?
        POSTHOG_LOGS_ENDPOINT
      elsif host.end_with?("/i/v1/logs")
        host
      else
        host.delete_suffix("/") + "/i/v1/logs"
      end

      exporter = OpenTelemetry::Exporter::OTLP::Logs::LogsExporter.new(
        endpoint: endpoint,
        headers: { "Authorization" => "Bearer #{token}" }
      )

      processor = OpenTelemetry::SDK::Logs::Export::BatchLogRecordProcessor.new(exporter)

      resource = OpenTelemetry::SDK::Resources::Resource.create(
        "service.name" => Rails.application.class.module_parent_name.underscore,
        "service.environment" => Rails.env.to_s
      )

      provider = OpenTelemetry::SDK::Logs::LoggerProvider.new(resource: resource)
      provider.add_log_record_processor(processor)

      @logger   = provider.logger(name: "ascension", version: "1.0.0")
      @provider = provider
      @enabled  = true

      Rails.logger.info("[OtelLogs] Initialized — shipping logs to #{endpoint}")
    rescue StandardError => e
      Rails.logger.warn("[OtelLogs] Failed to initialize: #{e.message}")
    end

    def shutdown!
      @provider&.shutdown
    end
  end
end

OtelLogs.setup!

# Ensure clean shutdown on process exit so the batch processor flushes
at_exit { OtelLogs.shutdown! }
