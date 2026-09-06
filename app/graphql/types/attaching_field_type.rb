# frozen_string_literal: true

module Types
  class AttachingFieldType < Types::BaseObject
    grants "uris:resources:read"

    field :name, String, null: false
    field :label, String, null: false
    field :kind, String, null: false, description: "string, integer or boolean."
    field :required, Boolean, null: false
    field :secret, Boolean, null: false, description: "Masked here, encrypted there, never read back."
    field :value, String, description: "What it holds until something is typed."
    field :help, String
    field :placeholder, String
  end
end
