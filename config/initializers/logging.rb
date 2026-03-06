# Structured JSON logging configuration
# Outputs logs in JSON format with credential redaction

module StructuredLogger
  class JsonFormatter < Logger::Formatter
    CREDENTIAL_PATTERNS = [
      /SLACK_BOT_TOKEN/i,
      /SLACK_SIGNING_SECRET/i,
      /OPENAI_API_KEY/i,
      /NOTION_API_KEY/i,
      /xoxb-[^\s]+/,  # Slack bot tokens
      /xoxp-[^\s]+/,  # Slack user tokens
      /sk-[^\s]+/,    # OpenAI API keys
      /secret_[^\s]+/ # Notion integration tokens
    ].freeze

    def call(severity, timestamp, progname, msg)
      log_entry = {
        timestamp: timestamp.utc.iso8601,
        level: severity,
        message: redact_credentials(msg.to_s),
        progname: progname
      }
      
      # Add context if message is a hash
      if msg.is_a?(Hash)
        log_entry[:message] = redact_credentials(msg[:message].to_s) if msg[:message]
        log_entry[:context] = redact_credentials(msg[:context]) if msg[:context]
      end
      
      "#{log_entry.to_json}\n"
    end

    private

    def redact_credentials(text)
      return text unless text.is_a?(String) || text.is_a?(Hash)
      
      if text.is_a?(Hash)
        text.transform_values { |v| redact_credentials(v) }
      else
        redacted = text.dup
        CREDENTIAL_PATTERNS.each do |pattern|
          redacted.gsub!(pattern, '[REDACTED]')
        end
        redacted
      end
    end
  end
end

# Configure Rails logger with JSON formatter
if Rails.env.production? || ENV['STRUCTURED_LOGGING'] == 'true'
  Rails.application.config.log_formatter = StructuredLogger::JsonFormatter.new
end
