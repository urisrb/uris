# frozen_string_literal: true

module Types
  class ReferenceType < Types::BaseObject
    grants "uris:catalog:read"

    field :id, ID, null: false
    field :resource, Types::ResourceType, null: false
    field :locator, GraphQL::Types::JSON, null: false
    field :locator_key, String
    field :filename, String, null: false
    field :content_type, String, null: false
    field :version, String
    field :changed_at, GraphQL::Types::ISO8601DateTime
    field :analyzed_at, GraphQL::Types::ISO8601DateTime
    field :role, String, null: false
    field :mime, String
    field :size, GraphQL::Types::BigInt
    field :content_url, String, null: false
    field :thumbnail_url, String

    def content_url
      "/references/#{object.id}/content"
    end

    def thumbnail_url
      return nil unless object.role == Reference::ORIGINAL

      thumbnail = object.feed.references.find { |held| held.role == Reference::THUMBNAIL }

      "/references/#{thumbnail.id}/content" if thumbnail
    end
  end
end
