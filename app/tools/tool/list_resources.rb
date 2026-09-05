module Tool
  class ListResources < Base
    tool_name "list_resources"
    scope "uris:resources:read"

    description <<~TEXT
      The places items live and the capabilities they can be asked for. Each entry is an
      instance — "my B2 bucket" — of a type such as s3. Call describe_resource for the
      commands a given one accepts.
    TEXT

    input_schema(properties: {})

    def self.call(server_context:)
      respond(server_context) do
        resources = Resource.active.order(:type, :key).map do |resource|
          {
            id: resource.id.to_s,
            type: resource.class.sti_name,
            key: resource.key,
            name: resource.name,
            capabilities: resource.capabilities,
            default_storage: resource.default_storage?,
            default_inference: resource.default_inference?,
            syncable: resource.syncable?,
            sync_interval: resource.sync_interval,
            next_sync_at: resource.next_sync_at,
            synced_at: resource.synced_at,
            syncing: resource.syncing?,
            checked_at: resource.checked_at,
            check_error: resource.check_error
          }
        end

        { count: resources.size, resources: resources }
      end
    end
  end
end
