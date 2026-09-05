module Tool
  class SyncResource < Base
    tool_name "sync_resource"
    scope "items:resources:command"
    starts_runs true

    description <<~TEXT
      Pull a resource's contents into the catalog as references, and queue each new one
      for analysis. Resumable: a sync interrupted by a deploy carries on from its cursor
      rather than starting over, so running it again is safe. A resource already syncing
      is left alone rather than started twice.
    TEXT

    input_schema(
      properties: { id: { type: "string", description: "The resource's id. It must be syncable." } },
      required: [ "id" ]
    )

    def self.call(id:, server_context:)
      respond(server_context, { id: id }) do
        resource = resource!(id)
        run = resource.sync!

        {
          id: resource.id.to_s,
          key: resource.key,
          queued: run ? true : false,
          run_id: run ? run.id.to_s : nil,
          syncing_since: resource.sync_started_at
        }
      end
    end
  end
end
