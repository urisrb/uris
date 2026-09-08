# frozen_string_literal: true

module Mutations
  class NoteFeed < BaseMutation
    MAX_NOTE = 10_000

    argument :id, ID, required: true
    argument :note, String, required: false,
             description: "Left off or blank, whatever was there is cleared."

    field :feed, Types::FeedType, null: false

    def resolve(id:, note: nil)
      written = note.to_s.strip

      refused("that note is longer than #{MAX_NOTE} characters") if written.length > MAX_NOTE

      feed = feed!(id)
      feed.update!(note: written.presence)

      { feed: feed }
    end
  end
end
