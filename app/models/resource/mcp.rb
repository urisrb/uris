class Resource
  class Mcp < Resource
    include PublicFetch

    SCOPE = "uris:mcp:call".freeze
    JOINER = "__".freeze
    PREFIX = /\A[a-z0-9][a-z0-9-]{0,30}\z/
    MAX_TOOLS = 40

    serves :tools

    def self.attaching
      {
        label: "An MCP server",
        blurb: "Somebody else's tools, offered beside the catalog's own. Checking it asks " \
               "what it can do; its tools then answer under this resource's key, so two " \
               "servers can both have a search without colliding.",
        names: "The prefix its tools answer under",
        fields: [
          field("url", "Address", required: true, placeholder: "https://mcp.example.com/mcp"),
          field("token", "Bearer token", secret: true)
        ]
      }
    end

    def self.command_schema
      { tools: {}, call: { name: "string", arguments: "json?" } }
    end

    validate :it_names_an_address
    validate :its_key_can_prefix_a_tool
    validate :it_does_not_point_at_us

    def url
      details.to_h["url"].to_s
    end

    def offered
      Array(details.to_h["tools"])
    end

    def check!
      discover!
      true
    end

    def discover!
      found = connected { |client| client.tools.first(MAX_TOOLS) }
      listed = found.map do |tool|
        { "name" => tool.name.to_s, "description" => tool.description.to_s,
          "input_schema" => tool.input_schema.to_h }
      end

      update!(details: details.to_h.merge("tools" => listed))
      listed
    end

    def invoke!(name, arguments = {})
      answered = connected do |client|
        client.call_tool(name: name, arguments: arguments.to_h.deep_stringify_keys)
      end

      answer(name, answered)
    end

    def proxied_tools
      offered.filter_map { |definition| proxy(definition) }
    end

    def command_tools
      { count: offered.size, tools: offered }
    end

    def command_call(name:, arguments: nil)
      invoke!(name, arguments || {})
    end

    private

      def connected
        client = MCP::Client.new(transport: transport)
        client.connect unless client.connected?

        yield client
      rescue MCP::Client::ServerError, MCP::Client::RequestHandlerError => e
        raise Resource::Failed, "#{key}: #{url} answered #{e.message}"
      rescue PublicFetch::Blocked
        raise
      rescue StandardError => e
        raise Resource::Failed, "#{key}: #{e.class} reaching #{url} — #{e.message}"
      end

      def transport
        MCP::Client::HTTP.new(url: permitted!(url).to_s, headers: headers)
      end

      def headers
        base = { "User-Agent" => "uris" }
        token = credentials.to_h["token"].presence

        token ? base.merge("Authorization" => "Bearer #{token}") : base
      end

      def answer(name, answered)
        result = answered.is_a?(Hash) ? answered["result"].to_h : {}

        texts = Array(result["content"]).filter_map do |part|
          part["text"].presence if part.is_a?(Hash)
        end

        if result["isError"]
          raise Resource::Failed, "#{key}: #{name} failed — #{texts.join(' ').truncate(200)}"
        end

        { content: texts }
      end

      def proxy(definition)
        remote = definition["name"].to_s
        return nil if remote.blank?

        held = id
        local = "#{key}#{JOINER}#{remote}"
        told = definition["description"].to_s
        shape = definition["input_schema"].to_h.symbolize_keys

        Class.new(Tool::Base) do
          tool_name local
          scope SCOPE
          description told
          input_schema(properties: shape[:properties].to_h, required: Array(shape[:required]))

          define_singleton_method(:call) do |server_context:, **arguments|
            respond(server_context, arguments) do
              Resource.find(held).invoke!(remote, arguments)
            end
          end
        end
      end

      def it_names_an_address
        errors.add(:details, "must name a url") if url.blank?
      end

      def its_key_can_prefix_a_tool
        return if key.to_s.match?(PREFIX)

        errors.add(:key, "is letters, numbers and dashes, so it can prefix a tool name")
      end

      def it_does_not_point_at_us
        suffix = ENV["URIS_HOST_SUFFIX"].presence
        return if suffix.nil? || url.blank?

        host = URI.parse(url).host.to_s
        return unless host == suffix || host.end_with?(".#{suffix}")

        errors.add(:details, "points back at uris, which would call itself")
      rescue URI::InvalidURIError
        errors.add(:details, "is not a url")
      end
  end
end
