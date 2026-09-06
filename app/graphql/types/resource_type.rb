# frozen_string_literal: true

module Types
  class ResourceType < Types::BaseObject
    grants "uris:resources:read"

    field :id, ID, null: false
    field :type, String, null: false, method: :type
    field :key, String, null: false
    field :name, String
    field :capabilities, [ String ], null: false
    field :items_count, Integer, null: false
    field :default_storage, Boolean, null: false
    field :default_inference, Boolean, null: false
    field :sync_interval, Integer
    field :next_sync_at, GraphQL::Types::ISO8601DateTime
    field :synced_at, GraphQL::Types::ISO8601DateTime
    field :syncing, Boolean, null: false, method: :syncing?
    field :archived_at, GraphQL::Types::ISO8601DateTime
    field :checked_at, GraphQL::Types::ISO8601DateTime
    field :check_error, String
    field :healthy, Boolean, null: false, method: :healthy?

    def capabilities
      object.capabilities.map(&:to_s)
    end

    def items_count
      Reference.where(resource_id: object.id).distinct.count(:item_id)
    end
  end
end
