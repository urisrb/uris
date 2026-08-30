module Tool
  class CancelRun < Base
    tool_name "cancel_run"
    scope "resources:command"

    description <<~TEXT
      Stop a run that is still going. A bulk job holds no token that can be revoked, so
      cancelling sets a flag the iteration reads on its next check rather than killing
      anything: the work stops within a few dozen objects, and whatever it had already
      done stays done. A run that has already finished is left alone.
    TEXT

    input_schema(
      properties: { id: { type: "string", description: "The run's id." } },
      required: [ "id" ]
    )

    def self.call(id:, server_context:)
      respond(server_context) do
        run = Run.find_by(id: id) || raise(ArgumentError, "no run with id #{id}")

        { cancelled: run.cancel!, **ListRuns.describe_run(run.reload) }
      end
    end
  end
end
