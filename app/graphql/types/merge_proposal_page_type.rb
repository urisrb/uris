# frozen_string_literal: true

module Types
  class MergeProposalPageType < Types::BaseObject
    field :nodes, [ Types::MergeProposalType ], null: false
    field :next_cursor, ID
    field :has_more, Boolean, null: false
  end
end
