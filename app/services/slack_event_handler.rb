require 'openssl'

class SlackEventHandler
  attr_reader :request_body, :timestamp, :signature

  def initialize(request_body:, timestamp:, signature:)
    @request_body = request_body
    @timestamp = timestamp
    @signature = signature
  end

  def valid_signature?
    return false if timestamp.blank? || signature.blank?
    
    # Verify timestamp is recent (within 5 minutes) to prevent replay attacks
    request_time = Time.at(timestamp.to_i)
    return false if (Time.now - request_time).abs > 300
    
    # Compute expected signature
    signing_secret = ENV['SLACK_SIGNING_SECRET']
    sig_basestring = "v0:#{timestamp}:#{request_body}"
    expected_signature = "v0=#{OpenSSL::HMAC.hexdigest('SHA256', signing_secret, sig_basestring)}"
    
    # Use constant-time comparison to prevent timing attacks
    ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature)
  end

  def handle_app_mention(event_data)
    # Validate event type
    unless event_data['type'] == 'app_mention'
      Rails.logger.warn("Received non-app_mention event: #{event_data['type']}")
      return { success: false, error: 'Invalid event type' }
    end

    # Extract required fields
    channel_id = event_data['channel']
    thread_ts = event_data['thread_ts'] || event_data['ts']
    user_id = event_data['user']
    text = event_data['text']

    # Validate required fields are present
    if channel_id.blank? || thread_ts.blank? || user_id.blank?
      Rails.logger.error("Missing required fields in event data: #{event_data}")
      return { success: false, error: 'Missing required fields' }
    end

    # Enqueue background job for PRD generation
    job = PrdGenerationJob.perform_later(
      channel_id: channel_id,
      thread_ts: thread_ts,
      user_id: user_id
    )

    Rails.logger.info("Enqueued PrdGenerationJob: #{job.job_id} for channel #{channel_id}, thread #{thread_ts}")
    
    { success: true, job_id: job.job_id }
  rescue StandardError => e
    Rails.logger.error("Error handling app_mention: #{e.message}\n#{e.backtrace.join("\n")}")
    { success: false, error: e.message }
  end
end
