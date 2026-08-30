# frozen_string_literal: true

module Mutations
  class SplitReference < BaseMutation
    argument :id, ID, required: true, description: "The reference to move to a thing of its own."

    field :thing, Types::ThingType, null: false

    def resolve(id:)
      reference = ThingReference.find_by(id: id) ||
                  refused("no reference with id #{id}")

      refused("a thing with one reference is already split") if
        reference.thing.references.size == 1

      { thing: reference.split!.thing }
    end
  end
end
