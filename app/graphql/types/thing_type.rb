# frozen_string_literal: true

module Types
  class ThingType < Types::BaseObject
    field :id, ID, null: false
    field :kind, String, null: false
    field :title, String
    field :locator, GraphQL::Types::JSON, null: false
    field :resource, Types::ResourceType
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
