# frozen_string_literal: true

# OtelLogDevice bridges Rails.logger writes to the OpenTelemetry Logs API.
#
# Rails formats log entries as strings like:
#   "I, [2024-01-01T00:00:00.000000 #1234]  INFO -- : message"
#
# This device parses the severity prefix and emits an OTel LogRecord via
# OtelLogs.logger. It is a no-op when OtelLogs is not initialized.
class OtelLogDevice
  SN = OpenTelemetry::Logs::SeverityNumber

  SEVERITY_MAP = {
    Logger::DEBUG => SN::SEVERITY_NUMBER_DEBUG,
    Logger::INFO  => SN::SEVERITY_NUMBER_INFO,
    Logger::WARN  => SN::SEVERITY_NUMBER_WARN,
    Logger::ERROR => SN::SEVERITY_NUMBER_ERROR,
    Logger::FATAL => SN::SEVERITY_NUMBER_FATAL
  }.freeze

  SEVERITY_TEXT_MAP = {
    Logger::DEBUG => "DEBUG",
    Logger::INFO  => "INFO",
    Logger::WARN  => "WARN",
    Logger::ERROR => "ERROR",
    Logger::FATAL => "FATAL"
  }.freeze

  # Rails calls write(message) where message is the formatted log string.
  def write(message)
    return unless OtelLogs.enabled?

    severity_number = parse_severity(message)
    severity_text   = SEVERITY_TEXT_MAP[severity_level_for(severity_number)] || "INFO"
    body            = strip_prefix(message)

    OtelLogs.logger.on_emit(
      timestamp: Time.now,
      severity_number: severity_number,
      severity_text: severity_text,
      body: body,
      attributes: { "log.source" => "rails.logger" }
    )
  rescue StandardError
    # Never let OTel errors affect the main log path
  end

  def close; end
  def reopen(_log_dest = nil); end

  private

  RAILS_PREFIX_TO_LEVEL = {
    "D" => Logger::DEBUG,
    "I" => Logger::INFO,
    "W" => Logger::WARN,
    "E" => Logger::ERROR,
    "F" => Logger::FATAL
  }.freeze

  def parse_severity(message)
    level = RAILS_PREFIX_TO_LEVEL[message[0]] || Logger::INFO
    SEVERITY_MAP[level] || SN::SEVERITY_NUMBER_INFO
  end

  def severity_level_for(severity_number)
    SEVERITY_MAP.key(severity_number)
  end

  # Strip the Rails log prefix (e.g. "I, [timestamp]  INFO -- : ") from the body.
  # Uses a simple split on " -- :" to avoid regex nested-repeat warnings.
  def strip_prefix(message)
    parts = message.to_s.split(" -- ", 2)
    parts.last&.sub(/\A\w*: /, "")&.strip || message.to_s.strip
  end
end
