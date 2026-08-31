module Tool
  class DescribeResource < Base
    tool_name "describe_resource"
    scope "resources:read"

    description <<~TEXT
      What one resource can be asked to do: its capabilities and the exact command
      vocabulary command_resource will accept for it. Argument types ending in ? are
      optional. Credentials are never returned.
    TEXT

    input_schema(
      properties: { id: { type: "string", description: "The resource's id, as returned by list_resources." } },
      required: [ "id" ]
    )

    def self.call(id:, server_context:)
      respond(server_context, { id: id }) do
        resource = resource!(id)

        resource.describe.merge(id: resource.id.to_s, syncable: resource.syncable?)
      end
    end
  end
end
