# frozen_string_literal: true

module Mutations
  class AnalyzeFeed < BaseMutation
    argument :id, ID, required: true

    field :analysis, Types::AnalysisType, null: false
    field :feed, Types::FeedType, null: false

    def resolve(id:)
      feed = feed!(id)

      { analysis: feed.analyze!, feed: feed }
    end
  end
end
