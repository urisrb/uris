# frozen_string_literal: true

module Mutations
  class CancelRun < BaseMutation
    argument :id, ID, required: true

    field :run, Types::RunType, null: false
    field :cancelled, Boolean, null: false

    def resolve(id:)
      run = run!(id)

      { cancelled: run.cancel!, run: run.reload }
    end
  end
end
