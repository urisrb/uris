# frozen_string_literal: true

module Mutations
  class SettleMergeProposal < BaseMutation
    argument :id, ID, required: true
    argument :accept, Boolean, required: true,
             description: "Merge the things this proposal named, or dismiss it."

    field :proposal, Types::MergeProposalType, null: false
    field :thing, Types::ThingType

    def resolve(id:, accept:)
      proposal = MergeProposal.find_by(id: id) ||
        refused("no merge proposal with id #{id}")

      return { proposal: proposal.tap(&:reject!), thing: nil } unless accept

      { proposal: proposal, thing: proposal.accept! }
    rescue MergeProposal::Stale => e
      proposal.settle!("stale")
      refused(e.message)
    end
  end
end
