class Agent
  class Dispatch
    Result = Data.define(:name, :arguments, :content, :ok, :error)

    def initialize(offered:, context:)
      @offered = offered
      @context = context
    end

    def call(raw)
      name = raw.to_h.dig("function", "name").to_s
      tool = @offered.find { |held| held.tool_name == name }

      return refused(name, {}, "no tool named #{name}. There is #{offered_names}.") if tool.nil?

      arguments = parsed(raw)
      return refused(name, {}, arguments) if arguments.is_a?(String)

      complaint = checked(tool, arguments)
      return refused(name, arguments, complaint) if complaint

      ran(tool, name, arguments)
    end

    private

      def offered_names
        @offered.map(&:tool_name).join(", ")
      end

      def parsed(raw)
        held = JSON.parse(raw.to_h.dig("function", "arguments").to_s)

        held.is_a?(Hash) ? held : {}
      rescue JSON::ParserError
        "the arguments were not valid JSON. Send a JSON object."
      end

      # The MCP server validates a call before it splats it into a tool. Doing it here too is
      # what stops an argument the model invented from raising out of the turn loop instead of
      # coming back as something it can correct.
      def checked(tool, arguments)
        schema = tool.input_schema
        return nil if schema.nil?

        missing = schema.missing_required_arguments(arguments)
        return "#{tool.tool_name} needs #{missing.join(', ')}." if missing.any?

        schema.validate_arguments(arguments)
        nil
      rescue MCP::Tool::InputSchema::ValidationError => e
        e.message
      end

      def declared(tool, arguments)
        wanted = tool.input_schema&.to_h&.dig(:properties)&.keys&.map(&:to_s)
        return arguments.symbolize_keys if wanted.blank?

        arguments.slice(*wanted).symbolize_keys
      end

      def ran(tool, name, arguments)
        response = tool.call(server_context: @context, **declared(tool, arguments))

        Result.new(name: name, arguments: arguments, content: said(response),
                   ok: !response.error?, error: (said(response) if response.error?))
      rescue ArgumentError => e
        refused(name, arguments, e.message)
      end

      def said(response)
        Array(response.content).filter_map { |part| part[:text] || part["text"] }.join("\n")
      end

      def refused(name, arguments, complaint)
        Result.new(name: name, arguments: arguments, ok: false, error: complaint,
                   content: { error: complaint }.to_json)
      end
  end
end
