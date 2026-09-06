class Agent
  class Refused < StandardError; end

  TURNS = 6
  READ_TOOLS = %w[search_items get_item].freeze

  SYSTEM = <<~TEXT.freeze
    You are the uris catalog agent. Use the tools to find what the request asks for.
    Call a tool rather than answering from memory. When you have enough, answer in one
    or two sentences and stop.
  TEXT

  Turn = Struct.new(:number, :calls, :said, keyword_init: true)

  attr_reader :turns_taken

  def initialize(grant:, inference: nil, tools: nil, promptable: nil, turns: TURNS, halted: nil)
    @grant = grant
    @inference = inference || Resource.for_role(Resource::OpenaiCompatible::AGENT_ROLE)
    @offered = tools || grant.tools.select { |tool| READ_TOOLS.include?(tool.tool_name) }
    @promptable = promptable
    @turns = turns
    @halted = halted
    @turns_taken = 0
  end

  def call(prompt)
    raise Refused, "no inference resource serves the agent role" if @inference.nil?

    messages = [ { role: "system", content: SYSTEM }, { role: "user", content: prompt.to_s } ]

    @turns.times do |index|
      return :halted if @halted&.call

      @turns_taken = index + 1
      message = @inference.converse(messages: messages, tools: declared, promptable: @promptable, turn: @turns_taken)
      calls = message["tool_calls"]

      if calls.blank?
        announce(Turn.new(number: @turns_taken, calls: [], said: message["content"].to_s))

        return message["content"].to_s
      end

      messages << message
      calls.each { |call| messages << answer(call) }

      announce(Turn.new(number: @turns_taken, calls: calls.map { |c| c.dig("function", "name") }, said: nil))
    end

    :ran_out
  end

  def inference_key = @inference&.key
  def offered_names = @offered.map(&:tool_name)

  private

    # The same schema an MCP client is given, from the same registry, so a tool cannot
    # behave one way over /mcp and another here.
    def declared
      @offered.map do |tool|
        {
          type: "function",
          function: {
            name: tool.tool_name,
            description: tool.description.to_s.strip,
            parameters: tool.input_schema.to_h
          }
        }
      end
    end

    # Dispatches through Tool.call, which re-checks the scope against Current.grant itself.
    # A model that names a tool it was not offered, or arguments that do not fit, is
    # refused here rather than trusted.
    def answer(call)
      name = call.dig("function", "name")
      tool = @offered.find { |candidate| candidate.tool_name == name }

      content =
        if tool.nil?
          { error: "no tool named #{name}" }.to_json
        else
          said(tool.call(server_context: context, **arguments(call)))
        end

      { role: "tool", tool_call_id: call["id"].to_s, name: name, content: content }
    end

    def arguments(call)
      parsed = JSON.parse(call.dig("function", "arguments").to_s)
      parsed.is_a?(Hash) ? parsed.symbolize_keys : {}
    rescue JSON::ParserError
      {}
    end

    def said(response)
      Array(response.content).filter_map { |part| part[:text] || part["text"] }.join("\n")
    end

    def context
      { tenant_id: @grant.tenant.id, scopes: @grant.scopes }
    end

    def announce(turn)
      return if @promptable.nil?

      UrisSchema.subscriptions.trigger(:agent_turned, { id: @promptable.id.to_s }, turn)
    rescue StandardError => e
      Rails.logger.warn "agent could not announce turn #{turn.number}: #{e.message}"
    end
end
