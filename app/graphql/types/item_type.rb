# frozen_string_literal: true

module Types
  class ItemType < Types::BaseObject
    grants "uris:catalog:read"

    SUMMARY = 400

    field :id, ID, null: false
    field :kind, String, null: false
    field :origin, String, null: false,
          description: "resource when synced from one, feed when a feed minted it."
    field :feed, Types::FeedType, description: "The feed that minted it, when it was minted."
    field :title, String
    field :references, [ Types::ReferenceType ], null: false
    field :analyzed_at, GraphQL::Types::ISO8601DateTime
    field :note, String, description: "What you wrote about it, in your own words."
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
