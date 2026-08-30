# frozen_string_literal: true

module Mutations
  class MergeThings < BaseMutation
    argument :id, ID, required: true, description: "The thing that survives."
    argument :other_id, ID, required: true, description: "The thing whose references move."

    field :thing, Types::ThingType, null: false

    def resolve(id:, other_id:)
      target = thing!(id)
      other = thing!(other_id)
      refused("a thing cannot merge into itself") if target.id == other.id

      { thing: target.merge!(other) }
    end
  end
end
