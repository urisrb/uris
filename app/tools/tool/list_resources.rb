module Tool
  class ListResources < Base
    tool_name "list_resources"
    scope "resources:read"

    description <<~TEXT
      The places things live and the capabilities they can be asked for. Each entry is an
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
            syncable: resource.syncable?
          }
        end

        { count: resources.size, resources: resources }
      end
    end
  end
end
