class SlackEventService
  class InvalidEventError < StandardError; end

  attr_reader :payload

  def initialize(payload)
    @payload = payload || {}
  end

  def normalized_event
    event = payload.fetch("event") { raise InvalidEventError, "Missing event" }

    team_id = payload["team_id"] || payload.dig("authorizations", 0, "team_id")
    channel = event["channel"]
    user = event["user"]
    text = event["text"]
    ts = event["ts"]
    thread_ts = event["thread_ts"] || ts

    raise InvalidEventError, "Missing channel or ts" if channel.blank? || thread_ts.blank?

    slack_thread_url = build_thread_url(team_id: team_id, channel: channel, thread_ts: thread_ts)

    {
      team_id: team_id,
      channel: channel,
      user: user,
      text: text,
      event_ts: ts,
      thread_ts: thread_ts,
      slack_thread_url: slack_thread_url
    }
  end

  private

  def build_thread_url(team_id:, channel:, thread_ts:)
    return nil if team_id.blank? || channel.blank? || thread_ts.blank?

    "https://app.slack.com/client/#{team_id}/#{channel}/thread/#{channel}-#{thread_ts}"
  end
end

