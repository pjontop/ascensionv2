# frozen_string_literal: true

# AppLog — structured business event logging via OpenTelemetry.
#
# Use this for deliberate, meaningful application events where you want
# structured attributes alongside the message (e.g. user IDs, job names,
# amounts). Falls back to Rails.logger when OTel is not enabled.
#
# Usage:
#   AppLog.info("user.signed_up", user_id: user.id, plan: "pro")
#   AppLog.warn("payment.retrying", attempt: 3, invoice_id: inv.id)
#   AppLog.error("job.failed", job: self.class.name, error: e.message)
#
module AppLog
  SN = OpenTelemetry::Logs::SeverityNumber

  class << self
    def debug(message, **attrs) = emit(SN::SEVERITY_NUMBER_DEBUG, "DEBUG", message, attrs)
    def info(message, **attrs)  = emit(SN::SEVERITY_NUMBER_INFO,  "INFO",  message, attrs)
    def warn(message, **attrs)  = emit(SN::SEVERITY_NUMBER_WARN,  "WARN",  message, attrs)
    def error(message, **attrs) = emit(SN::SEVERITY_NUMBER_ERROR, "ERROR", message, attrs)
    def fatal(message, **attrs) = emit(SN::SEVERITY_NUMBER_FATAL, "FATAL", message, attrs)

    private

    def emit(severity_number, severity_text, message, attrs)
      if OtelLogs.enabled?
        OtelLogs.logger.on_emit(
          timestamp: Time.now,
          severity_number: severity_number,
          severity_text: severity_text,
          body: message,
          attributes: attrs.transform_keys(&:to_s).merge("log.source" => "app_log")
        )
      else
        Rails.logger.public_send(severity_text.downcase, "[AppLog] #{message} #{attrs.inspect}")
      end
    rescue StandardError
      # Never let OTel errors surface to callers
    end
  end
end
