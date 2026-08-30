module Tool
  class SyncResource < Base
    tool_name "sync_resource"
    scope "resources:command"

    description <<~TEXT
      Pull a resource's contents into the catalog as references, and queue each new one
      for analysis. Resumable: a sync interrupted by a deploy carries on from its cursor
      rather than starting over, so running it again is safe.
    TEXT

    input_schema(
      properties: { id: { type: "string", description: "The resource's id. It must be syncable." } },
      required: [ "id" ]
    )

    def self.call(id:, server_context:)
      respond(server_context) do
        resource = resource!(id)
        resource.sync!

        { id: resource.id.to_s, key: resource.key, queued: true }
      end
    end
  end
end
