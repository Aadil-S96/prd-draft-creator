class SlackEventsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_slack_signature!

  def create
    payload = params.permit!.to_h

    if payload["type"] == "url_verification"
      render json: { challenge: payload["challenge"] }
      return
    end

    event = payload["event"] || {}

    case event["type"]
    when "app_mention"
      normalized = SlackEventService.new(payload).normalized_event

      PrdGenerationJob.perform_later(
        channel_id: normalized[:channel],
        thread_ts: normalized[:thread_ts],
        user_id: normalized[:user]
      )
    else
      Rails.logger.info("Unhandled Slack event type: #{event['type']}")
    end

    head :ok
  rescue SlackEventService::InvalidEventError => e
    Rails.logger.warn("Invalid Slack event: #{e.message}")
    head :bad_request
  end

  private

  def verify_slack_signature!
    signing_secret = ENV["SLACK_SIGNING_SECRET"]
    unless signing_secret
      Rails.logger.warn("SLACK_SIGNING_SECRET not set; skipping Slack signature verification")
      return
    end

    timestamp = request.headers["X-Slack-Request-Timestamp"]
    slack_signature = request.headers["X-Slack-Signature"]

    if timestamp.blank? || slack_signature.blank?
      head :unauthorized
      return
    end

    if (Time.now.to_i - timestamp.to_i).abs > 300
      head :unauthorized
      return
    end

    sig_basestring = "v0:#{timestamp}:#{request.raw_post}"
    computed_signature = "v0=" + OpenSSL::HMAC.hexdigest("SHA256", signing_secret, sig_basestring)

    Rack::Utils.secure_compare(computed_signature, slack_signature)
  rescue StandardError => e
    Rails.logger.error("Error verifying Slack signature: #{e.class} - #{e.message}")
    head :unauthorized
  end
end

