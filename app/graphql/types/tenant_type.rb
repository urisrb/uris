# frozen_string_literal: true

module Types
  class TenantType < Types::BaseObject
    field :id, ID, null: false
    field :subdomain, String, null: false
    field :name, String, null: false
  end
end
