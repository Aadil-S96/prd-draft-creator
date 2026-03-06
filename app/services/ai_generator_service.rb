class AiGeneratorService
  MAX_RETRIES = 2
  RATE_LIMIT_WAIT = 60 # seconds

  VALID_PROBLEM_TYPES = %w[conversion_drop tech_issue supply_constraint growth_opportunity other].freeze
  VALID_PRIORITIES = %w[P0 P1 P2].freeze
  REQUIRED_PRD_SECTIONS = [
    'Problem Statement',
    'Context',
    'Hypothesis Tree',
    'Proposed Solution',
    'Success Metrics',
    'Risks',
    'Open Questions'
  ].freeze

  class << self
    def generate(messages:)
      new(messages: messages).generate
    end
  end

  def initialize(messages:)
    @messages = messages
    @client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  end

  def generate
    attempt = 0
    
    loop do
      begin
        prd_data = call_openai_api
        validate_prd_data!(prd_data)
        return prd_data
      rescue ValidationError => e
        attempt += 1
        if attempt > MAX_RETRIES
          Rails.logger.error("Exhausted retries for AI generation due to validation errors: #{e.message}")
          raise
        end
        
        Rails.logger.warn("Validation error: #{e.message}, retrying (#{attempt}/#{MAX_RETRIES})")
      rescue OpenAI::Error => e
        attempt += 1
        if attempt > MAX_RETRIES
          Rails.logger.error("Exhausted retries for AI generation: #{e.message}")
          raise
        end
        
        if e.message.include?('429') || e.message.include?('rate_limit')
          Rails.logger.warn("Rate limited by OpenAI, waiting #{RATE_LIMIT_WAIT}s before retry #{attempt}/#{MAX_RETRIES}")
          sleep(RATE_LIMIT_WAIT)
        else
          backoff = 2 ** attempt
          Rails.logger.warn("OpenAI API error: #{e.message}, retrying in #{backoff}s (#{attempt}/#{MAX_RETRIES})")
          sleep(backoff)
        end
      end
    end
  end

  private

  attr_reader :messages, :client

  def call_openai_api
    conversation_text = format_conversation
    
    start_time = Time.now
    response = client.chat(
      parameters: {
        model: 'gpt-4-turbo-preview',
        messages: [
          { role: 'system', content: system_prompt },
          { role: 'user', content: user_prompt(conversation_text) }
        ],
        response_format: { type: 'json_object' },
        temperature: 0.7
      }
    )
    duration = Time.now - start_time
    
    Rails.logger.info("OpenAI API call completed in #{duration.round(2)}s")
    
    content = response.dig('choices', 0, 'message', 'content')
    JSON.parse(content)
  rescue JSON::ParserError => e
    Rails.logger.error("Failed to parse OpenAI response as JSON: #{e.message}")
    raise ValidationError, "Invalid JSON response from OpenAI"
  end

  def format_conversation
    messages.map do |msg|
      "#{msg[:username]} (#{msg[:timestamp]}): #{msg[:text]}"
    end.join("\n\n")
  end

  def system_prompt
    <<~PROMPT
      You are a product manager assistant. Analyze Slack conversations and generate structured Product Requirements Documents (PRDs).
      
      Your output must be valid JSON with the following structure:
      {
        "project_name": "A concise title for the project",
        "problem_type": "One of: conversion_drop, tech_issue, supply_constraint, growth_opportunity, other",
        "priority": "One of: P0, P1, P2",
        "summary": "A 2-3 sentence overview of the problem and proposed solution",
        "prd_markdown": "Full PRD in markdown format with required sections",
        "hypothesis_tree": [
          {
            "hypothesis": "Main hypothesis statement",
            "sub_hypotheses": ["Supporting hypothesis 1", "Supporting hypothesis 2"]
          }
        ]
      }
      
      The prd_markdown must include these sections in order:
      # <Project Name as Title>
      ## Problem Statement
      ## Context
      ## Hypothesis Tree
      ## Proposed Solution
      ## Success Metrics
      ## Risks
      ## Open Questions
    PROMPT
  end

  def user_prompt(conversation_text)
    <<~PROMPT
      Analyze this Slack conversation and generate a comprehensive PRD:

      #{conversation_text}

      Generate a JSON response following the specified structure. Be thorough and professional.
    PROMPT
  end

  def validate_prd_data!(data)
    # Check required fields
    required_fields = %w[project_name problem_type priority summary prd_markdown hypothesis_tree]
    missing_fields = required_fields - data.keys
    
    if missing_fields.any?
      raise ValidationError, "Missing required fields: #{missing_fields.join(', ')}"
    end

    # Validate problem_type
    unless VALID_PROBLEM_TYPES.include?(data['problem_type'])
      raise ValidationError, "Invalid problem_type: #{data['problem_type']}. Must be one of: #{VALID_PROBLEM_TYPES.join(', ')}"
    end

    # Validate priority
    unless VALID_PRIORITIES.include?(data['priority'])
      raise ValidationError, "Invalid priority: #{data['priority']}. Must be one of: #{VALID_PRIORITIES.join(', ')}"
    end

    # Validate PRD has a title (any top-level heading)
    prd_markdown = data['prd_markdown']
    unless prd_markdown.match?(/^#\s+.+/m)
      raise ValidationError, "PRD markdown missing a title heading"
    end

    # Validate required sections
    missing_sections = REQUIRED_PRD_SECTIONS.reject do |section|
      prd_markdown.match?(/##?\s*#{Regexp.escape(section)}/i)
    end
    
    if missing_sections.any?
      raise ValidationError, "PRD markdown missing required sections: #{missing_sections.join(', ')}"
    end

    # Validate hypothesis_tree structure
    unless data['hypothesis_tree'].is_a?(Array)
      raise ValidationError, "hypothesis_tree must be an array"
    end

    data['hypothesis_tree'].each_with_index do |item, index|
      unless item.is_a?(Hash) && item['hypothesis'].present?
        raise ValidationError, "hypothesis_tree[#{index}] must have a 'hypothesis' field"
      end
    end
  end

  class ValidationError < StandardError; end
end
