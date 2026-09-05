module Tool
  class GetItem < Base
    tool_name "get_item"
    scope "items:catalog:read"

    EXCERPT = 8_000

    description <<~TEXT
      Everything known about one item: every place it lives, what analysis extracted from
      each of them, and an excerpt of its text. A item groups references; the bytes stay in
      the resources they came from, so use export_items to get those back out.
    TEXT

    input_schema(
      properties: { id: { type: "string", description: "The item's id, as returned by search_items." } },
      required: [ "id" ]
    )

    def self.call(id:, server_context:)
      respond(server_context, { id: id }) do
        item = item!(id)

        summarize(item).merge(
          references: item.references.map do |reference|
            describe_reference(reference).merge(locator: reference.locator, steps: steps(reference))
          end,
          text: item.body_text&.truncate(EXCERPT)
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
