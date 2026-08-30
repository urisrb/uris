# frozen_string_literal: true

module Types
  class ResourceType < Types::BaseObject
    field :id, ID, null: false
    field :type, String, null: false, method: :type
    field :key, String, null: false
    field :name, String
    field :capabilities, [ String ], null: false
    field :things_count, Integer, null: false

    def capabilities
      object.capabilities.map(&:to_s)
    end

    def things_count
      ThingReference.where(resource_id: object.id).distinct.count(:thing_id)
    end
  end
end
