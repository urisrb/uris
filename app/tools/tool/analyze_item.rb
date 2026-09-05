module Tool
  class AnalyzeItem < Base
    tool_name "analyze_item"
    scope "uris:catalog:write"
    starts_runs true

    description <<~TEXT
      Queue one item for analysis. Analysis is incremental — steps that already hold a
      result are skipped — so re-running a item costs almost nothing and repairs one
      whose earlier run errored.
    TEXT

    input_schema(
      properties: { id: { type: "string", description: "The item's id." } },
      required: [ "id" ]
    )

    def self.call(id:, server_context:)
      respond(server_context, { id: id }) do
        item = item!(id)
        run = item.analyze!

        {
          id: item.id.to_s,
          run_id: run.id.to_s,
          queued: item.references.size,
          analyzed_at: item.analyzed_at
        }
      end
    end
  end
end
