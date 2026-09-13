# frozen_string_literal: true

module Mutations
  class AskCatalog < BaseMutation
    MAX_QUESTION = 500
    TITLE = 200

    argument :question, String, required: true

    field :feed, Types::FeedType, null: false,
          description: "The note the question is kept as. What the answer cites is connected to it."
    field :analysis, Types::AnalysisType, null: false,
          description: "The pass that answers it. Watch it with analysisProgressed."

    def resolve(question:)
      text = question.to_s.squish
      refused("a question needs something in it") if text.empty?
      refused("that question is longer than #{MAX_QUESTION} characters") if text.length > MAX_QUESTION

      feed = Feed.create!(type: Feed::NOTE, key: text, title: text.truncate(TITLE), origin: "feed")

      { feed: feed, analysis: feed.analyze!(cause: "ask") }
    end
  end
end
