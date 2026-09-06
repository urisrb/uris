# frozen_string_literal: true

module Types
  class AttachingType < Types::BaseObject
    grants "uris:resources:read"

    description "What one type of resource needs before it can answer."

    field :type, String, null: false
    field :label, String, null: false
    field :blurb, String, null: false
    field :names, String, null: false, description: "What the key means for this type."
    field :capabilities, [ String ], null: false
    field :syncs, Boolean, null: false
    field :brokered, Boolean, null: false,
          description: "Connected in the browser rather than by typing a credential."
    field :fields, [ Types::AttachingFieldType ], null: false
  end
end
