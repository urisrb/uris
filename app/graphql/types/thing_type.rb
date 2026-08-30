# frozen_string_literal: true

module Types
  class ThingType < Types::BaseObject
    field :id, ID, null: false
    field :kind, String, null: false
    field :title, String
    field :references, [ Types::ThingReferenceType ], null: false
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
