# frozen_string_literal: true

module Mutations
  class SplitReference < BaseMutation
    argument :id, ID, required: true, description: "The reference to move to a item of its own."

    field :item, Types::ItemType, null: false

    def resolve(id:)
      reference = Reference.find_by(id: id) ||
                  refused("no reference with id #{id}")

      refused("a item with one reference is already split") if
        reference.item.references.size == 1

      { item: reference.split!.item }
    end
  end
end
