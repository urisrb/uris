# frozen_string_literal: true

module Mutations
  class CheckResource < BaseMutation
    argument :id, ID, required: true

    field :resource, Types::ResourceType, null: false
    field :ok, Boolean, null: false

    def resolve(id:)
      resource = resource!(id)

      { ok: resource.check, resource: resource }
    end
  end
end
