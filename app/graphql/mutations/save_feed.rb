# frozen_string_literal: true

module Mutations
  class SaveFeed < BaseMutation
    argument :id, ID, required: false, description: "Left off, a feed is created."
    argument :key, String, required: false, description: "Its address, as /buy."
    argument :title, String, required: false
    argument :prompt, String, required: false
    argument :turns, Integer, required: false
    argument :timeout, Integer, required: false,
             description: "Seconds an analysis of it may run, from a minute to a day. Null gets the default."
    argument :interval, Integer, required: false,
             description: "Seconds between runs. Zero or null runs it only by hand."

    field :feed, Types::FeedType, null: true

    def resolve(id: nil, key: nil, title: nil, prompt: nil, turns: nil, interval: nil, **given)
      feed = id ? feed!(id) : Feed.new(type: Feed::ADDRESS)
      feed.key = addressed(key) if key.present?
      feed.title = title if title
      feed.key ||= addressed(title)
      feed.timeout = given[:timeout] if given.key?(:timeout)

      refused(feed.errors.full_messages.join(", ")) unless feed.save

      settle(feed, prompt: prompt, turns: turns, interval: interval)

      { feed: feed }
    end

    private

      def addressed(given)
        held = given.to_s.strip.downcase.parameterize

        held.start_with?("/") ? held : "/#{held}"
      end

      def settle(feed, prompt:, turns:, interval:)
        held = feed.schedule || feed.build_schedule(prompt: "")
        held.prompt = prompt if prompt
        held.turns = turns if turns
        held.interval = interval.to_i.positive? ? interval : nil

        refused(held.errors.full_messages.join(", ")) unless held.save
      end
  end
end
