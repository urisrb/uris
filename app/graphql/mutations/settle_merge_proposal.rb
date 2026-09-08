# frozen_string_literal: true

module Mutations
  class SettleMergeProposal < BaseMutation
    argument :id, ID, required: true
    argument :accept, Boolean, required: true,
             description: "Merge the feeds this proposal named, or dismiss it."

    field :proposal, Types::MergeProposalType, null: false
    field :feed, Types::FeedType

    def resolve(id:, accept:)
      proposal = MergeProposal.find_by(id: id) ||
        refused("no merge proposal with id #{id}")

      return { proposal: proposal.tap(&:reject!), feed: nil } unless accept

      { proposal: proposal, feed: proposal.accept! }
    rescue MergeProposal::Stale => e
      proposal.settle!("stale")
      refused(e.message)
    end
  end
end
