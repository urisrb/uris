# frozen_string_literal: true

module Mutations
  class RunFeed < BaseMutation
    argument :id, ID, required: true

    field :run, Types::RunType, null: false

    def resolve(id:)
      { run: Feed.find(id).run! }
    end
  end
end
