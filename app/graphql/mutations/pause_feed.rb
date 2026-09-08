# frozen_string_literal: true

module Mutations
  class PauseFeed < BaseMutation
    argument :id, ID, required: true
    argument :paused, Boolean, required: true

    field :feed, Types::FeedType, null: false

    def resolve(id:, paused:)
      feed = feed!(id)
      schedule = feed.schedule || refused("#{feed.key} has nothing to pause")

      paused ? schedule.pause! : schedule.resume!

      { feed: feed }
    end
  end
end
