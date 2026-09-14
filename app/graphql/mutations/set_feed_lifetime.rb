# frozen_string_literal: true

module Mutations
  class SetFeedLifetime < BaseMutation
    argument :id, ID, required: true
    argument :lasts, String, required: false,
             description: "\"forever\", or how many days from now it lasts before it is forgotten. Left off, forever."

    field :feed, Types::FeedType, null: false

    def resolve(id:, lasts: nil)
      feed = feed!(id)

      { feed: feed.lasts!(lasts.presence || Feed::FOREVER) }
    rescue ArgumentError => e
      refused(e.message)
    end
  end
end
