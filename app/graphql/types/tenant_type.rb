# frozen_string_literal: true

module Types
  class TenantType < Types::BaseObject
    description "The tenant this request resolved to, from the subdomain"

    field :id, ID, null: false
    field :subdomain, String, null: false
    field :name, String, null: false
  end
end
