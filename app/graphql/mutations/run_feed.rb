# frozen_string_literal: true

module Mutations
  class RunFeed < BaseMutation
    argument :id, ID, required: true

    field :analysis, Types::AnalysisType, null: false

    def resolve(id:)
      { analysis: feed!(id).analyze!(cause: "manual") }
    end
  end
end
