# frozen_string_literal: true

module Mutations
  class ProposeMerges < BaseMutation
    field :run, Types::RunType, null: false

    def resolve
      run = Run.start!(kind: "dedupe")
      ProposeMergesJob.perform_later(Current.tenant.id, run.id)

      { run: run }
    end
  end
end
