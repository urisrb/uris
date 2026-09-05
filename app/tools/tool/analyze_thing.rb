module Tool
  class AnalyzeThing < Base
    tool_name "analyze_thing"
    scope "things:catalog:write"
    starts_runs true

    description <<~TEXT
      Queue one thing for analysis. Analysis is incremental — steps that already hold a
      result are skipped — so re-running a thing costs almost nothing and repairs one
      whose earlier run errored.
    TEXT

    input_schema(
      properties: { id: { type: "string", description: "The thing's id." } },
      required: [ "id" ]
    )

    def self.call(id:, server_context:)
      respond(server_context, { id: id }) do
        thing = thing!(id)
        run = thing.analyze!

        {
          id: thing.id.to_s,
          run_id: run.id.to_s,
          queued: thing.references.size,
          analyzed_at: thing.analyzed_at
        }
      end
    end
  end
end
