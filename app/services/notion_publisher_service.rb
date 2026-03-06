class NotionPublisherService
  MAX_RETRIES = 3
  INITIAL_BACKOFF = 1 # seconds

  class << self
    def publish(project_name:, prd_markdown:, user: nil)
      new(project_name: project_name, prd_markdown: prd_markdown, user: user).publish
    end
  end

  def initialize(project_name:, prd_markdown:, user: nil)
    @project_name = project_name
    @prd_markdown = prd_markdown
    api_key = user&.notion_api_key.presence || ENV["NOTION_API_KEY"]
    @database_id = user&.notion_database_id.presence || ENV["NOTION_DATABASE_ID"]
    @client = Notion::Client.new(token: api_key)
  end

  def publish
    attempt = 0
    
    loop do
      begin
        start_time = Time.now
        page = create_notion_page
        duration = Time.now - start_time
        
        Rails.logger.info("Notion page created in #{duration.round(2)}s: #{page['url']}")
        
        return page['url']
      rescue Notion::Api::Errors::TooManyRequests => e
        attempt += 1
        if attempt > MAX_RETRIES
          Rails.logger.error("Exhausted retries for Notion publish due to rate limiting")
          raise
        end
        
        retry_after = extract_retry_after(e) || exponential_backoff(attempt)
        Rails.logger.warn("Rate limited by Notion API, waiting #{retry_after}s before retry #{attempt}/#{MAX_RETRIES}")
        sleep(retry_after)
      rescue Notion::Api::Errors::NotionError, Faraday::Error => e
        attempt += 1
        if attempt > MAX_RETRIES || !retryable_error?(e)
          Rails.logger.error("Failed to publish to Notion: #{e.message}")
          raise
        end
        
        backoff = exponential_backoff(attempt)
        Rails.logger.warn("Notion API error: #{e.message}, retrying in #{backoff}s (#{attempt}/#{MAX_RETRIES})")
        sleep(backoff)
      end
    end
  end

  private

  attr_reader :project_name, :prd_markdown, :client, :database_id

  def create_notion_page
    blocks = markdown_to_notion_blocks(prd_markdown)
    
    client.create_page(
      parent: { database_id: database_id },
      properties: {
        title: {
          title: [
            {
              text: { content: project_name }
            }
          ]
        }
      },
      children: blocks
    )
  end

  def markdown_to_notion_blocks(markdown)
    blocks = []
    lines = markdown.split("\n")
    i = 0
    
    while i < lines.length
      line = lines[i].strip
      
      if line.empty?
        i += 1
        next
      end
      
      # Headers
      if line.start_with?('# ')
        blocks << heading_block(1, line[2..-1])
      elsif line.start_with?('## ')
        blocks << heading_block(2, line[3..-1])
      elsif line.start_with?('### ')
        blocks << heading_block(3, line[4..-1])
      # Code blocks
      elsif line.start_with?('```')
        code_lines = []
        language = line[3..-1].strip
        i += 1
        
        while i < lines.length && !lines[i].strip.start_with?('```')
          code_lines << lines[i]
          i += 1
        end
        
        blocks << code_block(code_lines.join("\n"), language)
      # Bulleted lists
      elsif line.start_with?('- ') || line.start_with?('* ')
        blocks << bulleted_list_item_block(line[2..-1])
      # Numbered lists
      elsif line.match?(/^\d+\.\s/)
        text = line.sub(/^\d+\.\s/, '')
        blocks << numbered_list_item_block(text)
      # Regular paragraphs
      else
        blocks << paragraph_block(line)
      end
      
      i += 1
    end
    
    blocks
  end

  def heading_block(level, text)
    heading_type = case level
                   when 1 then 'heading_1'
                   when 2 then 'heading_2'
                   else 'heading_3'
                   end
    
    {
      object: 'block',
      type: heading_type,
      heading_type => {
        rich_text: [{ type: 'text', text: { content: text } }]
      }
    }
  end

  def paragraph_block(text)
    {
      object: 'block',
      type: 'paragraph',
      paragraph: {
        rich_text: [{ type: 'text', text: { content: text } }]
      }
    }
  end

  def bulleted_list_item_block(text)
    {
      object: 'block',
      type: 'bulleted_list_item',
      bulleted_list_item: {
        rich_text: [{ type: 'text', text: { content: text } }]
      }
    }
  end

  def numbered_list_item_block(text)
    {
      object: 'block',
      type: 'numbered_list_item',
      numbered_list_item: {
        rich_text: [{ type: 'text', text: { content: text } }]
      }
    }
  end

  def code_block(code, language)
    {
      object: 'block',
      type: 'code',
      code: {
        rich_text: [{ type: 'text', text: { content: code } }],
        language: language.presence || 'plain text'
      }
    }
  end

  def exponential_backoff(attempt)
    [INITIAL_BACKOFF * (2 ** (attempt - 1)), 32].min
  end

  def extract_retry_after(error)
    # Try to extract retry-after from error response
    error.response&.headers&.[]('retry-after')&.to_i
  rescue
    nil
  end

  def retryable_error?(error)
    error.is_a?(Notion::Api::Errors::UnavailableError) ||
      error.message.include?('timeout') ||
      error.message.include?('connection')
  end
end
