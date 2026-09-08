# frozen_string_literal: true

module Mutations
  class MergeFeeds < BaseMutation
    argument :id, ID, required: true, description: "The feed that survives."
    argument :other_id, ID, required: true, description: "The feed whose references move."

    field :feed, Types::FeedType, null: false

    def resolve(id:, other_id:)
      target = feed!(id)
      other = feed!(other_id)
      refused("a feed cannot merge into itself") if target.id == other.id

      { feed: target.merge!(other) }
    end
  end
end
