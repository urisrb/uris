module Tool
  class GetThing < Base
    tool_name "get_thing"
    scope "things:read"

    EXCERPT = 8_000

    description <<~TEXT
      Everything known about one thing: where it lives, what analysis extracted from it,
      and an excerpt of its text. A thing is a reference — the bytes stay in the resource
      it came from, so use export_things to get those back out.
    TEXT

    input_schema(
      properties: { id: { type: "string", description: "The thing's id, as returned by search_things." } },
      required: [ "id" ]
    )

    def self.call(id:, server_context:)
      respond(server_context) do
        thing = thing!(id)

        summarize(thing).merge(
          locator: thing.locator,
          resource: thing.resource&.key,
          steps: steps(thing),
          text: thing.body_text&.truncate(EXCERPT)
        )
      end
    end

    def self.steps(thing)
      thing.analysis.fetch("steps", {}).transform_values do |step|
        step.key?("error") ? { "error" => step["error"]["message"] } : step["result"]
      end
    end
  end
end
