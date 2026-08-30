# frozen_string_literal: true

module Mutations
  class AnalyzeThing < BaseMutation
    argument :id, ID, required: true

    field :run, Types::RunType, null: false
    field :thing, Types::ThingType, null: false

    def resolve(id:)
      thing = thing!(id)

      { run: thing.analyze!, thing: thing }
    end
  end
end
