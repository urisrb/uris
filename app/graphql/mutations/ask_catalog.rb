# frozen_string_literal: true

module Mutations
  class AskCatalog < BaseMutation
    MAX_QUESTION = 500
    TITLE = 200

    argument :question, String, required: true
    argument :feed_id, ID, required: false,
             description: "A note already asked. The question follows on from what it was asked before."

    field :feed, Types::FeedType, null: false,
          description: "The note the question is kept as. What the answer cites is connected to it."
    field :analysis, Types::AnalysisType, null: false,
          description: "The pass that answers it. Watch it with analysisProgressed."

    def resolve(question:, feed_id: nil)
      text = question.to_s.squish
      refused("a question needs something in it") if text.empty?
      refused("that question is longer than #{MAX_QUESTION} characters") if text.length > MAX_QUESTION

      feed = feed_id ? asked!(feed_id) : Feed.create!(type: Feed::NOTE, key: text, title: text.truncate(TITLE), origin: "feed")

      { feed: feed, analysis: feed.ask!(text) }
    rescue ArgumentError => e
      refused(e.message)
    end

    private

      def asked!(id)
        feed = feed!(id)
        refused("#{feed.title || feed.key} was never asked, so there is nothing to follow on from") unless feed.asked?

        feed
      end
  end
end
