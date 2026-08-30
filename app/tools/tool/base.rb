module Tool
  class Base < MCP::Tool
    EXPECTED = [
      Grant::Denied,
      ArgumentError,
      ActiveRecord::RecordNotFound,
      Resource::Failed
    ].freeze

    class << self
      def scope(value = nil)
        @scope = value if value
        @scope
      end

      def respond(server_context)
        server_context.fetch(:grant).permit!(scope)

        text(yield.to_json)
      rescue *EXPECTED => e
        text(e.message, error: true)
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
          locator_key: thing.locator_key,
          resource_id: thing.resource_id&.to_s,
          analyzed_at: thing.analyzed_at
        }
      end

      def selector_from(query: nil, kind: nil, resource_id: nil)
        { "query" => query, "kind" => kind, "resource_id" => resource_id }.compact
      end
    end
  end
end
