# frozen_string_literal: true

module Mutations
  class SetFeedTimeout < BaseMutation
    argument :id, ID, required: true
    argument :seconds, Integer, required: false,
             description: "How long an analysis of it may run, from a minute to a day. Left off, it gets the default."

    field :feed, Types::FeedType, null: false

    def resolve(id:, seconds: nil)
      feed = feed!(id)
      feed.timeout = seconds

      refused(feed.errors.full_messages.join(", ")) unless feed.save

      { feed: feed }
    end
  end
end
