# frozen_string_literal: true

module Mutations
  class SyncResource < BaseMutation
    argument :id, ID, required: true

    field :run, Types::RunType
    field :resource, Types::ResourceType, null: false

    def resolve(id:)
      resource = resource!(id)
      refused("#{resource.key} cannot sync") unless resource.syncable?

      run = resource.sync!

      { run: run || nil, resource: resource }
    end
  end
end
