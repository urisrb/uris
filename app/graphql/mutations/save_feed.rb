# frozen_string_literal: true

module Mutations
  class SaveFeed < BaseMutation
    argument :id, ID, required: false, description: "Left off, a feed is created."
    argument :slug, String, required: false
    argument :name, String, required: false
    argument :prompt, String, required: false
    argument :turns, Integer, required: false
    argument :interval, Integer, required: false,
             description: "Seconds between runs. Zero or null runs it only by hand."

    field :feed, Types::FeedType, null: true

    def resolve(id: nil, interval: nil, **attributes)
      feed = id ? Feed.find(id) : Feed.new
      feed.assign_attributes(attributes.compact)
      feed.interval = interval.to_i.positive? ? interval : nil

      refused(feed.errors.full_messages.join(", ")) unless feed.save

      feed.schedule_next!

      { feed: feed }
    end
  end
end
