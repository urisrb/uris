# frozen_string_literal: true

module Mutations
  class MergeItems < BaseMutation
    argument :id, ID, required: true, description: "The item that survives."
    argument :other_id, ID, required: true, description: "The item whose references move."

    field :item, Types::ItemType, null: false

    def resolve(id:, other_id:)
      target = item!(id)
      other = item!(other_id)
      refused("a item cannot merge into itself") if target.id == other.id

      { item: target.merge!(other) }
    end
  end
end
