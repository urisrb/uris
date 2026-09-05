module McpTransports
  INSTRUCTIONS = <<~TEXT.freeze
    items is one searchable index across everything its owner keeps, wherever it lives.

    A item is a reference, not the bytes: the catalog holds where something lives and what
    analysis understood about it, while the original stays in the resource it came from.
    So searching is cheap and reading the bytes back means exporting them.

    Start with search_items. Use list_resources to see where items come from, and
    describe_resource before command_resource — each resource type has its own vocabulary.

    Credentials never travel through a tool call. Connecting a resource happens in the
    browser, and nothing here will accept a secret as an argument.
  TEXT

  SESSION_HEADER = "Mcp-Session-Id".freeze
  SESSION_TTL = 30.minutes
  LOCK = Mutex.new

  class << self
    def for(tenant:, grant:)
      key = [ tenant.id, grant.scopes.sort ]

      LOCK.synchronize { held[key] ||= build(tenant, grant) }
    end

    def claim(session_id, subject)
      return if session_id.blank?

      Rails.cache.fetch(cache_key(session_id), expires_in: SESSION_TTL) { subject.to_s }
    end

    def holds?(session_id, subject)
      held_subject = Rails.cache.read(cache_key(session_id))

      held_subject.nil? || held_subject == subject.to_s
    end

    def forget(session_id)
      Rails.cache.delete(cache_key(session_id))
    end

    def reset!
      LOCK.synchronize do
        held.each_value { |transport| transport.close rescue nil }
        @held = {}
      end
    end

    private

      def cache_key(session_id)
        "mcp:session:#{session_id}"
      end

      def held
        @held ||= {}
      end

      def build(tenant, grant)
        MCP::Server::Transports::StreamableHTTPTransport.new(
          server(tenant, grant),
          enable_json_response: true,
          dns_rebinding_protection: false,
          session_request_validator: ->(_request, session_id) {
            holds?(session_id, Current.grant&.subject)
          }
        )
      end

      def server(tenant, grant)
        MCP::Server.new(
          name: "uris",
          title: "uris",
          instructions: INSTRUCTIONS,
          tools: grant.tools,
          server_context: { tenant_id: tenant.id, scopes: grant.scopes }
        )
      end
  end
end
