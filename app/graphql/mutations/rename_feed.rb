# frozen_string_literal: true

module Mutations
  class RenameFeed < BaseMutation
    MAX_TITLE = 200

    argument :id, ID, required: true
    argument :title, String, required: true

    field :feed, Types::FeedType, null: false

    def resolve(id:, title:)
      named = title.to_s.strip

      refused("a feed needs something to be called") if named.empty?
      refused("that name is longer than #{MAX_TITLE} characters") if named.length > MAX_TITLE

      feed = feed!(id)
      feed.update!(title: named)

      { feed: feed }
    end
  end
end
