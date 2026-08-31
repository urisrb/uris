# frozen_string_literal: true

module Types
  class MergeProposalType < Types::BaseObject
    grants "things:read"

    field :id, ID, null: false
    field :blocking_key, String, null: false
    field :reason, String, null: false
    field :status, String, null: false
    field :settled_at, GraphQL::Types::ISO8601DateTime
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
    field :things, [ Types::ThingType ], null: false
    field :current, Boolean, null: false

    def current
      object.current?
    end
  end
end
