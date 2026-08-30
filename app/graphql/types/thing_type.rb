# frozen_string_literal: true

module Types
  class ThingType < Types::BaseObject
    description "A reference to something you own, wherever it lives"

    field :id, ID, null: false
    field :kind, String, null: false, description: "What this thing is — pdf, email, image"
    field :title, String
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false
  end
end
