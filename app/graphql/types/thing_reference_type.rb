# frozen_string_literal: true

module Types
  class ThingReferenceType < Types::BaseObject
    grants "things:catalog:read"

    field :id, ID, null: false
    field :resource, Types::ResourceType, null: false
    field :locator, GraphQL::Types::JSON, null: false
    field :locator_key, String
    field :filename, String, null: false
    field :content_type, String, null: false
    field :version, String
    field :changed_at, GraphQL::Types::ISO8601DateTime
    field :analyzed_at, GraphQL::Types::ISO8601DateTime
    field :analysis, GraphQL::Types::JSON, null: false
    field :content_url, String, null: false
    field :thumbnail_url, String

    def content_url
      "/references/#{object.id}/content"
    end

    def thumbnail_url
      "/references/#{object.id}/thumbnail" if object.thumbnail?
    end
  end
end
