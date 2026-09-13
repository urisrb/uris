# frozen_string_literal: true

module Types
  class AttachingOptionType < Types::BaseObject
    grants "uris:resources:read"

    field :value, String, null: false
    field :label, String, null: false
  end
end
