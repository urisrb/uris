# frozen_string_literal: true

module Types
  class AttachingConditionType < Types::BaseObject
    grants "uris:resources:read"

    field :field, String, null: false
    field :values, [ String ], null: false
  end
end
