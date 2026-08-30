# frozen_string_literal: true

module Types
  class ThingReferenceType < Types::BaseObject
    field :id, ID, null: false
    field :resource, Types::ResourceType, null: false
    field :locator, GraphQL::Types::JSON, null: false
    field :locator_key, String
    field :analyzed_at, GraphQL::Types::ISO8601DateTime
  end
end
