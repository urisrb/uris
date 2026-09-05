module Tool
  class ExportThings < Base
    tool_name "export_things"
    scope "things:resources:command"
    starts_runs true

    description <<~TEXT
      Copy the bytes behind matching things into a storage resource — the way back out.
      The selector is the same grammar search_things uses; every argument you leave off
      widens it, and no arguments at all means the whole catalog into this tenant's
      default storage. Each copy is catalogued as another reference to the thing it
      came from, so a thing already written to the destination is left alone.
    TEXT

    input_schema(
      properties: {
        destination_id: {
          type: "string",
          description: "A storage resource to write into. Defaults to this tenant's default storage."
        },
        **SELECTOR_SCHEMA
      }
    )

    def self.call(server_context:, destination_id: nil, query: nil, kind: nil, resource_id: nil,
                  folder: nil, since: nil, before: nil)
      selected = { query: query, kind: kind, resource_id: resource_id,
                   folder: folder, since: since, before: before }

      respond(server_context, selected.merge(destination_id: destination_id)) do
        destination = if destination_id.present?
          resource!(destination_id).storage!
        else
          Resource.default_storage!
        end

        selector = selector_from(**selected)
        run = Run.start!(kind: "export", resource: destination, selector: selector)
        ExportThingsJob.perform_later(destination.tenant_id, destination.id, selector, run.id)

        { run_id: run.id.to_s, destination: destination.key, selector: selector, queued: true }
      end
    end
  end
end
