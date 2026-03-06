# Configuration for Slack PRD Generator
# Validates presence of required environment variables on startup

module SlackPrdConfig
  REQUIRED_ENV_VARS = {
    'SLACK_BOT_TOKEN' => 'Slack bot token for API authentication',
    'SLACK_SIGNING_SECRET' => 'Slack signing secret for webhook verification',
    'OPENAI_API_KEY' => 'OpenAI API key for PRD generation',
    'NOTION_API_KEY' => 'Notion API key for page creation',
    'NOTION_DATABASE_ID' => 'Notion database ID for PRD storage'
  }.freeze

  class << self
    def validate!
      missing_vars = REQUIRED_ENV_VARS.keys.select { |var| ENV[var].blank? }
      
      if missing_vars.any?
        error_message = "Missing required environment variables: #{missing_vars.join(', ')}\n\n"
        error_message += "Please set the following:\n"
        missing_vars.each do |var|
          error_message += "  #{var}: #{REQUIRED_ENV_VARS[var]}\n"
        end
        
        raise ConfigurationError, error_message
      end
    end
  end

  class ConfigurationError < StandardError; end
end

# Validate configuration on startup
# Skip in test, during asset precompilation, and during db:migrate
unless Rails.env.test? || ENV["SECRET_KEY_BASE_DUMMY"].present? || ENV["SKIP_ENV_VALIDATION"].present?
  SlackPrdConfig.validate!
end
