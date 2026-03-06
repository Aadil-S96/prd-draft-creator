class PrdGenerationJob < ApplicationJob
  queue_as :default

  def perform(channel_id:, thread_ts:, user_id:)
    start_time = Time.now
    
    Rails.logger.info("Starting PRD generation for channel: #{channel_id}, thread: #{thread_ts}, user: #{user_id}")
    
    # Step 1: Fetch thread messages
    messages = ThreadFetcherService.fetch(channel_id: channel_id, thread_ts: thread_ts)
    Rails.logger.info("Fetched #{messages.count} messages from thread")
    
    # Step 2: Generate PRD using AI
    prd_data = AiGeneratorService.generate(messages: messages)
    Rails.logger.info("Generated PRD: #{prd_data['project_name']}")
    
    # Step 3: Publish to Notion (use per-user config if available)
    user = User.find_by(id: user_id) # user_id from Slack won't match DB id yet, fallback to env
    notion_url = NotionPublisherService.publish(
      project_name: prd_data['project_name'],
      prd_markdown: prd_data['prd_markdown'],
      user: user
    )
    Rails.logger.info("Published to Notion: #{notion_url}")
    
    # Step 4: Create project record
    slack_thread_url = fetch_thread_permalink(channel_id, thread_ts)
    
    project = Project.create!(
      name: prd_data['project_name'],
      slack_thread_url: slack_thread_url,
      notion_url: notion_url,
      problem_type: prd_data['problem_type'],
      priority: prd_data['priority'],
      status: :draft,
      owner: user_id,
      summary: prd_data['summary'],
      hypothesis_tree: prd_data['hypothesis_tree']
    )
    
    Rails.logger.info("Created project record: #{project.id}")
    
    # Step 5: Post success notification to Slack
    post_success_notification(channel_id, thread_ts, notion_url)
    
    duration = Time.now - start_time
    Rails.logger.info("PRD generation completed in #{duration.round(2)}s")
    
  rescue StandardError => e
    duration = Time.now - start_time
    
    Rails.logger.error({
      message: "PRD generation failed after #{duration.round(2)}s",
      error: e.message,
      backtrace: e.backtrace.first(10),
      context: {
        channel_id: channel_id,
        thread_ts: thread_ts,
        user_id: user_id
      }
    }.to_json)
    
    # Post error notification to Slack
    post_error_notification(channel_id, thread_ts, e.message)
    
    # Re-raise to trigger job retry mechanism
    raise
  end

  private

  def post_success_notification(channel_id, thread_ts, notion_url)
    client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    
    client.chat_postMessage(
      channel: channel_id,
      thread_ts: thread_ts,
      text: "PRD created: #{notion_url}"
    )
    
    Rails.logger.info("Posted success notification to Slack")
  rescue StandardError => e
    # Don't fail the job if notification fails (graceful degradation)
    Rails.logger.error("Failed to post success notification to Slack: #{e.message}")
  end

  def post_error_notification(channel_id, thread_ts, error_message)
    client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    
    client.chat_postMessage(
      channel: channel_id,
      thread_ts: thread_ts,
      text: "Failed to generate PRD: #{error_message}. Please try again or contact support."
    )
  rescue StandardError => e
    Rails.logger.error("Failed to post error notification to Slack: #{e.message}")
  end

  def fetch_thread_permalink(channel_id, thread_ts)
    client = Slack::Web::Client.new(token: ENV['SLACK_BOT_TOKEN'])
    response = client.chat_getPermalink(channel: channel_id, message_ts: thread_ts)
    response['permalink']
  rescue StandardError => e
    Rails.logger.warn("Failed to fetch Slack permalink, using fallback: #{e.message}")
    "https://slack.com/app_redirect?channel=#{channel_id}&message_ts=#{thread_ts}"
  end

end
