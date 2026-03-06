require "net/http"
require "uri"
require "json"

class SlackClient
  class SlackError < StandardError; end

  API_BASE = "https://slack.com/api".freeze

  def initialize(token: ENV["SLACK_BOT_TOKEN"])
    @token = token
  end

  def fetch_thread(channel:, thread_ts:)
    response = get("conversations.replies", channel: channel, ts: thread_ts)
    ensure_ok!(response)
    response.fetch("messages", [])
  end

  def post_message(channel:, text:, thread_ts: nil)
    body = {
      channel: channel,
      text: text
    }
    body[:thread_ts] = thread_ts if thread_ts

    response = post("chat.postMessage", body)
    ensure_ok!(response)
    response
  end

  private

  attr_reader :token

  def get(path, params = {})
    uri = URI.join(API_BASE + "/", path)
    uri.query = URI.encode_www_form(params) if params.any?

    request = Net::HTTP::Get.new(uri)
    authorize(request)

    perform_request(uri, request)
  end

  def post(path, body = {})
    uri = URI.join(API_BASE + "/", path)

    request = Net::HTTP::Post.new(uri)
    authorize(request)
    request["Content-Type"] = "application/json"
    request.body = JSON.dump(body)

    perform_request(uri, request)
  end

  def authorize(request)
    raise SlackError, "SLACK_BOT_TOKEN is not set" if token.blank?

    request["Authorization"] = "Bearer #{token}"
  end

  def perform_request(uri, request)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.read_timeout = 10
    http.open_timeout = 5

    response = http.request(request)
    json = JSON.parse(response.body)
    json
  rescue JSON::ParserError => e
    raise SlackError, "Failed to parse Slack response: #{e.message}"
  rescue StandardError => e
    raise SlackError, "Slack request failed: #{e.class} - #{e.message}"
  end

  def ensure_ok!(response)
    return if response["ok"]

    error = response["error"] || "unknown_error"
    raise SlackError, "Slack API error: #{error}"
  end
end

