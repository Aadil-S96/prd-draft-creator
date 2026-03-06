class SlackWebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :require_login

  def events
    # Handle URL verification challenge (must happen before signature check)
    request_body = request.raw_post
    parsed_body = JSON.parse(request_body) rescue {}

    if parsed_body['type'] == 'url_verification'
      render json: { challenge: parsed_body['challenge'] }, status: :ok
      return
    end
    timestamp = request.headers['X-Slack-Request-Timestamp']
    signature = request.headers['X-Slack-Signature']

    # Validate signature
    handler = SlackEventHandler.new(
      request_body: request_body,
      timestamp: timestamp,
      signature: signature
    )

    unless handler.valid_signature?
      Rails.logger.warn("Invalid Slack signature for request")
      render json: { error: 'Invalid signature' }, status: :unauthorized
      return
    end

    # Handle app_mention events
    event_data = params[:event]
    
    if event_data && event_data[:type] == 'app_mention'
      result = handler.handle_app_mention(event_data.to_unsafe_h)
      
      if result[:success]
        Rails.logger.info("Successfully handled app_mention event, job_id: #{result[:job_id]}")
        render json: { ok: true }, status: :ok
      else
        Rails.logger.error("Failed to handle app_mention event: #{result[:error]}")
        render json: { error: result[:error] }, status: :bad_request
      end
    else
      # Acknowledge other event types but don't process them
      Rails.logger.info("Received non-app_mention event: #{event_data&.[](:type)}")
      render json: { ok: true }, status: :ok
    end
  rescue StandardError => e
    Rails.logger.error("Error processing Slack webhook: #{e.message}\n#{e.backtrace.join("\n")}")
    render json: { error: 'Internal server error' }, status: :internal_server_error
  end
end
