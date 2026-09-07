class Resource
  class Slack < Api
    API = "https://slack.com/api".freeze
    CHANNELS = 200
    MESSAGES = 200
    REPLIES = 200
    PEOPLE = 200
    PEOPLE_PAGES = 5
    KINDS = "public_channel,private_channel".freeze

    # Slack answers 200 and says no in the body, so a status code decides nothing here.
    BUSY = %w[ratelimited service_unavailable fatal_error internal_error].freeze
    MISSING = %w[channel_not_found thread_not_found message_not_found].freeze

    def self.api
      API
    end

    def self.service
      "Slack"
    end

    def self.capabilities
      []
    end

    def self.attaching
      {
        label: "Slack",
        blurb: "Threads from the channels the app has been invited to, each one an item. A bot " \
               "token reads what it was invited to and nothing else.",
        names: "A name for it",
        fields: [
          token_field("Bot token",
                      help: "Needs channels:read, channels:history and users:read. A bot still " \
                            "has to be invited to each channel.",
                      placeholder: "xoxb-…"),
          field("channels", "Only these channels",
                help: "One name per line. Left empty, every channel the bot is in is catalogued.")
        ]
      }
    end

    def self.command_schema
      {
        list: { channel: "string?", limit: "integer?" },
        get: { key: "string" }
      }
    end

    def wanted_channels
      details["channels"].to_s.split(/[\s,]+/).filter_map { |held| held.delete_prefix("#").presence }
    end

    def check!
      identity = called("/auth.test")

      raise Resource::Unusable, "#{key}: the token names no workspace" if identity["team"].blank?

      true
    end

    def each_page(cursor: nil, prefix: nil)
      channel, held = resume(cursor)
      reached = channel.nil?

      channels.each do |found|
        reached ||= found["id"] == channel
        next unless reached

        walk(found, found["id"] == channel ? held : nil) { |batch, mark| yield batch, mark }
      end
    end

    def locator_for(message)
      {
        "channel" => message.fetch("channel"),
        "channel_name" => message["channel_name"],
        "ts" => message["ts"],
        "user" => message["user"],
        "replies" => message["reply_count"].to_i,
        "latest_reply" => message["latest_reply"]
      }
    end

    def locator_key_for(message)
      return message.to_s unless message.is_a?(Hash)

      "#{message.fetch('channel')}/#{message['ts']}"
    end

    # A thread grows after it is written, so its version is the conversation rather than the
    # moment it started. A new reply is a new version, and the item is read again.
    def version_for(locator)
      held = locator.to_h

      [ held["ts"], held["replies"], held["latest_reply"] ].compact.join(":").presence
    end

    def kind_for(_message)
      "text"
    end

    def title_for(message)
      return message.to_s unless message.is_a?(Hash)

      channel = message["channel_name"].presence || message["channel"]
      opening = said(message).to_s.squish.truncate(80)

      [ "##{channel}", opening.presence ].compact.join(" — ")
    end

    def download(locator)
      channel = locator.fetch("channel")
      found = called("/conversations.replies", channel: channel, ts: locator.fetch("ts"),
                                               limit: REPLIES)

      StringIO.new(flattened(Array(found["messages"]).map { |message| spoken(message) }))
    end

    def command_list(channel: nil, limit: nil)
      count = (limit || 30).to_i.clamp(1, MESSAGES)

      return { "channels" => channels.map { |found| described(found) } } if channel.blank?

      found = channels.find { |held| held["name"] == channel.delete_prefix("#") || held["id"] == channel }

      raise Api::Gone, "#{key}: no channel #{channel}" if found.nil?

      history = called("/conversations.history", channel: found["id"], limit: count)

      {
        "channel" => described(found),
        "threads" => roots(Array(history["messages"]), found).map { |message| outline(message) }
      }
    end

    def command_get(key:)
      channel, ts = key.to_s.split("/")

      raise ArgumentError, "#{key} is not channel/timestamp" if channel.blank? || ts.blank?

      { "key" => key, "text" => download("channel" => channel, "ts" => ts).read }
    end

    private

      def called(path, **query)
        answered = api_get(path, **query)

        return answered if answered["ok"]

        raise refusal(answered["error"].to_s, path)
      end

      def refusal(error, path)
        said = "#{key}: #{path} answered #{error.presence || 'not ok'}"

        return Resource::Failed.new("#{said} — worth another attempt") if BUSY.include?(error)
        return Api::Gone.new(said) if MISSING.include?(error)

        Resource::Unusable.new(said)
      end

      def channels
        @channels ||= gather("/conversations.list", "channels",
                             types: KINDS, exclude_archived: true, limit: CHANNELS)
                        .select { |found| wanted?(found) }
      end

      def wanted?(found)
        return false unless found["is_member"]

        named = wanted_channels

        named.empty? || named.include?(found["name"])
      end

      def gather(path, holds, pages: nil, **query)
        held = []
        cursor = nil
        walked = 0

        loop do
          found = called(path, **query, cursor: cursor)
          held += Array(found[holds])
          cursor = found.dig("response_metadata", "next_cursor").presence
          walked += 1

          break if cursor.nil? || (pages && walked >= pages)
        end

        held
      end

      def walk(channel, cursor)
        held = cursor

        loop do
          found = called("/conversations.history", channel: channel["id"], limit: MESSAGES,
                                                   cursor: held)
          held = found.dig("response_metadata", "next_cursor").presence
          batch = roots(Array(found["messages"]), channel)

          yield batch, "#{channel['id']}:#{held}" if batch.any?

          break if held.nil?
        end
      end

      def roots(messages, channel)
        messages.select { |message| root?(message) }.map do |message|
          message.merge("channel" => channel["id"], "channel_name" => channel["name"])
        end
      end

      def root?(message)
        message["subtype"].blank? &&
          (message["thread_ts"].blank? || message["thread_ts"] == message["ts"])
      end

      def resume(cursor)
        return [ nil, nil ] if cursor.blank?

        channel, held = cursor.to_s.split(":", 2)

        [ channel.presence, held.presence ]
      end

      def spoken(message)
        "#{who(message['user'])}: #{said(message)}".strip
      end

      def said(message)
        text = message["text"].to_s
        attached = Array(message["attachments"]).filter_map { |held| held["fallback"] }
        files = Array(message["files"]).filter_map { |held| held["name"] }

        [ text, attached, files ].flatten.compact_blank.join("\n")
      end

      def who(id)
        return "someone" if id.blank?

        people.fetch(id, id)
      end

      def people
        @people ||= gather("/users.list", "members", pages: PEOPLE_PAGES, limit: PEOPLE)
                      .to_h { |member| [ member["id"], named(member) ] }
      rescue Resource::Failed
        {}
      end

      def named(member)
        member.dig("profile", "display_name").presence ||
          member.dig("profile", "real_name").presence ||
          member["name"].presence || member["id"]
      end

      def described(channel)
        {
          "id" => channel["id"],
          "name" => channel["name"],
          "topic" => channel.dig("topic", "value").presence,
          "members" => channel["num_members"]
        }.compact
      end

      def outline(message)
        {
          "key" => locator_key_for(message),
          "ts" => message["ts"],
          "user" => who(message["user"]),
          "replies" => message["reply_count"].to_i,
          "text" => said(message).to_s.squish.truncate(200)
        }
      end
  end
end
