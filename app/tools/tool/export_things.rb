module Tool
  class ExportThings < Base
    tool_name "export_things"
    scope "resources:command"

    description <<~TEXT
      Copy the bytes behind matching things into a storage resource — the way back out.
      The selector is the same grammar search_things uses; every argument you leave off
      widens it, and no arguments at all means the whole catalog.
    TEXT

    input_schema(
      properties: {
        destination_id: { type: "string", description: "A storage resource to write into." },
        query: { type: "string", description: "Words to match, as in search_things." },
        kind: { type: "string", description: "Restrict to one kind." },
        resource_id: { type: "string", description: "Restrict to things from one resource." }
      },
      required: [ "destination_id" ]
    )

    def self.call(destination_id:, server_context:, query: nil, kind: nil, resource_id: nil)
      respond(server_context) do
        destination = resource!(destination_id).storage!

        selector = selector_from(query: query, kind: kind, resource_id: resource_id)
        ExportThingsJob.perform_later(destination.tenant_id, destination.id, selector)

        { destination: destination.key, selector: selector, queued: true }
      end
    end
  end
end
