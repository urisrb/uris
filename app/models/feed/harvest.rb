class Feed
  # The write half of a feed run. The model is offered read tools only, so nothing it emits
  # can add to a feed or mint an item — this does, after the read phase has finished, from
  # what the agent actually looked at.
  class Harvest
    Result = Struct.new(:selected, :minted, keyword_init: true)

    def initialize(feed:, run: nil)
      @feed = feed
      @run = run
    end

    # Items the agent fetched during its turns are what it decided were worth looking at,
    # so they are what the feed keeps. Reading what the run actually did, rather than
    # trusting the model to report it, keeps the record and the claim the same thing.
    def call(looked_at)
      selected = Item.where(id: Array(looked_at).uniq).to_a
      selected.each { |item| keep(item) }

      Result.new(selected: selected, minted: [])
    end

    def mint(title:, kind: "text")
      item = Item.create!(title: title, kind: kind, origin: "feed", feed: @feed, run: @run)

      keep(item)
      item
    end

    private

      def keep(item)
        FeedItem.find_or_create_by!(feed: @feed, item: item) { |held| held.run = @run }
      end
  end
end
