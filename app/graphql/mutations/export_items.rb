# frozen_string_literal: true

module Mutations
  class ExportItems < BaseMutation
    argument :destination_id, ID, required: false,
             description: "Where to write. Left off, this tenant's default storage."
    argument :query, String, required: false
    argument :kind, String, required: false
    argument :resource_id, ID, required: false

    field :run, Types::RunType, null: false

    def resolve(destination_id: nil, query: nil, kind: nil, resource_id: nil)
      destination = destination_id.present? ? resource!(destination_id) : Resource.default_storage
      refused("this tenant has no default storage resource") if destination.nil?
      refused("#{destination.key} is not storage") unless destination.storage?

      selector = { "query" => query, "kind" => kind, "resource_id" => resource_id }.compact
      run = Run.start!(kind: "export", resource: destination, selector: selector)
      ExportItemsJob.perform_later(destination.tenant_id, destination.id, selector, run.id)

      { run: run }
    end
  end
end
