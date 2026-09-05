# frozen_string_literal: true

module Mutations
  class AnalyzeItem < BaseMutation
    argument :id, ID, required: true

    field :run, Types::RunType, null: false
    field :item, Types::ItemType, null: false

    def resolve(id:)
      item = item!(id)

      { run: item.analyze!, item: item }
    end
  end
end
