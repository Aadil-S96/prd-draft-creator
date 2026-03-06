class ThreadFetcherService
  MAX_RETRIES = 3
  INITIAL_BACKOFF = 1 # seconds

  class << self
    def fetch(channel_id:, thread_ts:)
      new(channel_id: channel_id, thread_ts: thread_ts).fetch
    end
  end

  def initialize(channel_id:, thread_ts:)
    @channel_id = channel_id
    @thread_ts = thread_ts
    @client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    @user_cache = {}
  end

  def fetch
    messages = fetch_thread_messages
    format_messages(messages)
  rescue StandardError => e
    Rails.logger.error("Failed to fetch thread after all retries: #{e.message}\n#{e.backtrace.join("\n")}")
    post_error_to_slack("Failed to fetch thread. Please try again later.")
    raise
  end

  private

  attr_reader :channel_id, :thread_ts, :client, :user_cache

  def fetch_thread_messages
    attempt = 0
    
    loop do
      begin
        start_time = Time.now
        response = client.conversations_replies(channel: channel_id, ts: thread_ts)
        duration = Time.now - start_time
        
        Rails.logger.info("Slack API conversations.replies: #{response.messages.count} messages, #{duration.round(2)}s")
        
        return response.messages
      rescue Slack::Web::Api::Errors::TooManyRequestsError => e
        attempt += 1
        if attempt > MAX_RETRIES
          Rails.logger.error("Exhausted retries for thread fetch due to rate limiting")
          raise
        end
        
        retry_after = e.response.headers['retry-after']&.to_i || exponential_backoff(attempt)
        Rails.logger.warn("Rate limited by Slack API, waiting #{retry_after}s before retry #{attempt}/#{MAX_RETRIES}")
        sleep(retry_after)
      rescue Slack::Web::Api::Errors::SlackError => e
        attempt += 1
        if attempt > MAX_RETRIES || !retryable_error?(e)
          Rails.logger.error("Failed to fetch thread: #{e.message}")
          raise
        end
        
        backoff = exponential_backoff(attempt)
        Rails.logger.warn("Slack API error: #{e.message}, retrying in #{backoff}s (#{attempt}/#{MAX_RETRIES})")
        sleep(backoff)
      end
    end
  end

  def format_messages(messages)
    messages.map do |message|
      {
        username: fetch_username(message['user']),
        timestamp: Time.at(message['ts'].to_f).utc.iso8601,
        text: message['text']
      }
    end.sort_by { |msg| msg[:timestamp] }
  end

  def fetch_username(user_id)
    return 'Unknown' if user_id.blank?
    
    # Check cache first
    return user_cache[user_id] if user_cache.key?(user_id)
    
    # Fetch from Slack API
    begin
      response = client.users_info(user: user_id)
      username = response.user.name || response.user.real_name || user_id
      user_cache[user_id] = username
      username
    rescue StandardError => e
      Rails.logger.warn("Failed to fetch username for #{user_id}: #{e.message}")
      user_cache[user_id] = user_id # Fallback to user ID
      user_id
    end
  end

  def exponential_backoff(attempt)
    [INITIAL_BACKOFF * (2 ** (attempt - 1)), 32].min
  end

  def retryable_error?(error)
    # Retry on server errors (5xx) but not on client errors (4xx)
    error.is_a?(Slack::Web::Api::Errors::ServerError) ||
      error.message.include?('timeout') ||
      error.message.include?('connection')
  end

  def post_error_to_slack(message)
    client.chat_postMessage(
      channel: channel_id,
      thread_ts: thread_ts,
      text: message
    )
  rescue StandardError => e
    Rails.logger.error("Failed to post error message to Slack: #{e.message}")
  end
end
