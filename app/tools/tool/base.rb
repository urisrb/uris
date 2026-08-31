module Tool
  class OverBudget < StandardError; end

  class Base < MCP::Tool
    EXPECTED = [
      Grant::Denied,
      OverBudget,
      ArgumentError,
      ActiveRecord::RecordNotFound,
      Resource::Failed
    ].freeze

    class << self
      def scope(value = nil)
        @scope = value if value
        @scope
      end

      def starts_runs(value = nil)
        @starts_runs = value unless value.nil?
        @starts_runs
      end

      def respond(_server_context, arguments = {})
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        grant = Current.grant or raise Grant::Denied, "this call carries no grant"
        grant.permit!(scope)
        within_budget!(grant)

        result = yield

        audit(grant, arguments, "ok", started)
        text(result.to_json)
      rescue *EXPECTED => e
        audit(Current.grant, arguments, refused?(e) ? "denied" : "error", started, e.message)

        text(e.message, error: true)
      end

      def refused?(error)
        error.is_a?(Grant::Denied) || error.is_a?(OverBudget)
      end

      def within_budget!(grant)
        return unless starts_runs

        limit = Rails.configuration.things.run_budget
        return if limit.zero?

        key = [ "mcp:runs", Current.tenant.id, grant.subject, Time.current.to_i / 3600 ].join(":")
        spent = Rails.cache.increment(key, 1, expires_in: 1.hour)

        return if spent.nil? || spent <= limit

        raise OverBudget,
              "this token has started #{spent - 1} runs in the last hour, and #{limit} is the ceiling"
      end

      def audit(grant, arguments, status, started, detail = nil)
        AuditEvent.record(
          channel: "mcp", action: tool_name, status: status, scope: scope,
          grant: grant, context: Current.audit,
          arguments: arguments, detail: detail,
          duration_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        )
      end

      def text(body, error: false)
        MCP::Tool::Response.new([ { type: "text", text: body } ], error: error)
      end

      def thing!(id)
        Thing.find_by(id: id) || raise(ArgumentError, "no thing with id #{id}")
      end

      def resource!(id)
        Resource.active.find_by(id: id) || raise(ArgumentError, "no resource with id #{id}")
      end

      def summarize(thing)
        {
          id: thing.id.to_s,
          kind: thing.kind,
          title: thing.title,
          analyzed_at: thing.analyzed_at,
          references: thing.references.map { |reference| describe_reference(reference) }
        }
      end

      def describe_reference(reference)
        {
          id: reference.id.to_s,
          resource_id: reference.resource_id.to_s,
          resource: reference.resource.key,
          locator_key: reference.locator_key,
          analyzed_at: reference.analyzed_at,
          changed_at: reference.changed_at
        }
      end

      def selector_from(query: nil, kind: nil, resource_id: nil)
        { "query" => query, "kind" => kind, "resource_id" => resource_id }.compact
      end
    end
  end
end
