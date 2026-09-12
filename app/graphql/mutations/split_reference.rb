# frozen_string_literal: true

module Mutations
  class SplitReference < BaseMutation
    argument :id, ID, required: true, description: "The reference to move to a feed of its own."

    field :feed, Types::FeedType, null: false

    def resolve(id:)
      reference = Reference.find_by(id: id) ||
                  refused("no reference with id #{id}")

      refused("a feed with one reference is already split") if
        reference.feed.references.originals.size == 1

      { feed: reference.split!.feed }
    end
  end
end
