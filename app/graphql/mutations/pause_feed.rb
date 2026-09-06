# frozen_string_literal: true

module Mutations
  class PauseFeed < BaseMutation
    argument :id, ID, required: true
    argument :paused, Boolean, required: true

    field :feed, Types::FeedType, null: false

    def resolve(id:, paused:)
      feed = Feed.find(id)
      paused ? feed.pause! : feed.resume!

      { feed: feed }
    end
  end
end
