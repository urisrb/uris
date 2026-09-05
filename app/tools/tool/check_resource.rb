module Tool
  class CheckResource < Base
    tool_name "check_resource"
    scope "items:resources:read"

    description <<~TEXT
      Ask a resource whether it still works — that its endpoint answers, its credentials
      are accepted, and it holds the permission its adapter needs. Cheap and read-only:
      a bucket HEAD rather than a listing. The answer is recorded on the resource, so
      list_resources reports when each was last checked and what failed.
    TEXT

    input_schema(
      properties: { id: { type: "string", description: "The resource's id." } },
      required: [ "id" ]
    )

    def self.call(id:, server_context:)
      respond(server_context, { id: id }) do
        resource = resource!(id)
        ok = resource.check

        {
          id: resource.id.to_s,
          key: resource.key,
          ok: ok,
          checked_at: resource.checked_at,
          error: resource.check_error
        }
      end
    end
  end
end
