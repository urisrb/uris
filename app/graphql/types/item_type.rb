# frozen_string_literal: true

module Types
  class ItemType < Types::BaseObject
    grants "items:catalog:read"

    SUMMARY = 400

    field :id, ID, null: false
    field :kind, String, null: false
    field :title, String
    field :references, [ Types::ReferenceType ], null: false
    field :analyzed_at, GraphQL::Types::ISO8601DateTime
    field :summary, String
    field :thumbnail_url, String
    field :created_at, GraphQL::Types::ISO8601DateTime, null: false

    def summary
      object.body_text&.squish&.truncate(SUMMARY)
    end

    def thumbnail_url
      reference = object.references.find(&:thumbnail?)

      "/references/#{reference.id}/thumbnail" if reference
    end
  end
end
