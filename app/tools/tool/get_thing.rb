module Tool
  class GetThing < Base
    tool_name "get_thing"
    scope "things:read"

    EXCERPT = 8_000

    description <<~TEXT
      Everything known about one thing: every place it lives, what analysis extracted from
      each of them, and an excerpt of its text. A thing groups references; the bytes stay in
      the resources they came from, so use export_things to get those back out.
    TEXT

    input_schema(
      properties: { id: { type: "string", description: "The thing's id, as returned by search_things." } },
      required: [ "id" ]
    )

    def self.call(id:, server_context:)
      respond(server_context, { id: id }) do
        thing = thing!(id)

        summarize(thing).merge(
          references: thing.references.map do |reference|
            describe_reference(reference).merge(locator: reference.locator, steps: steps(reference))
          end,
          text: thing.body_text&.truncate(EXCERPT)
        )
      end
    end

    def self.steps(reference)
      reference.analysis.fetch("steps", {}).transform_values do |step|
        step.key?("error") ? { "error" => step["error"]["message"] } : step["result"]
      end
    end
  end
end
