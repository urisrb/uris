module Tool
  class ListRuns < Base
    tool_name "list_runs"
    scope "items:resources:read"

    description <<~TEXT
      What the work you started is doing. Every tool that answers `queued` names a run,
      and this is where that run says whether it is still going, how many items it has
      got through, and what stopped it if something did. Newest first.
    TEXT

    input_schema(
      properties: {
        kind: { type: "string", description: "sync, export or analyze." },
        status: { type: "string", description: "queued, running, done, failed or cancelled." },
        limit: { type: "integer", description: "How many to return. 20 by default." }
      }
    )

    def self.call(server_context:, kind: nil, status: nil, limit: nil)
      respond(server_context, { kind: kind, status: status, limit: limit }) do
        scope = Run.newest_first
        scope = scope.where(kind: kind) if kind.present?
        scope = scope.where(status: status) if status.present?

        runs = scope.limit((limit || 20).to_i.clamp(1, 100)).map { |run| describe_run(run) }

        { count: runs.size, runs: runs }
      end
    end

    def self.describe_run(run)
      {
        id: run.id.to_s,
        kind: run.kind,
        status: run.status,
        resource: run.resource&.key,
        selector: run.selector,
        processed: run.processed,
        error: run.error,
        started_at: run.started_at,
        finished_at: run.finished_at,
        deadline: run.deadline
      }
    end
  end
end
