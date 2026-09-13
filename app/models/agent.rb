class Agent
  class Refused < StandardError; end

  TURNS = 6
  FLAILING = 3
  READ_TOOLS = %w[search feed connect resource].freeze

  SYSTEM = <<~TEXT.freeze
    You are the uris catalog agent. Use the tools to find what the request asks for.
    Call a tool rather than answering from memory. When you have enough, answer in one
    or two sentences and stop.
  TEXT

  LAST_TURN = <<~TEXT.freeze
    You have no turns left and no tools. Answer the request from what you have already
    read, in one or two sentences. If you never found it, say so plainly.
  TEXT

  Answer = Data.define(:said, :reason, :turns, :calls) do
    def answered? = reason == :answered

    def read
      calls.select { |call| call.ok && call.name == "feed" }
           .filter_map { |call| call.arguments[:id] || call.arguments["id"] }
           .uniq
    end
  end

  attr_reader :turns_taken, :calls

  def initialize(grant:, inference: nil, tools: nil, analysis: nil, turns: TURNS, halted: nil, unfinished: nil)
    @grant = grant
    @inference = inference || Resource.for_role(Resource::OpenaiCompatible::AGENT_ROLE)
    @offered = tools || grant.tools.select { |tool| READ_TOOLS.include?(tool.tool_name) }
    @analysis = analysis
    @turns = turns.to_i.clamp(1, 32)
    @halted = halted
    @unfinished = unfinished
    @pressed = Set.new
    @turns_taken = 0
    @calls = []
    @flailed = 0
  end

  def call(prompt)
    raise Refused, "no inference resource serves the agent role" if @inference.nil?

    transcript = Transcript.new(system: SYSTEM, prompt: prompt)

    @turns.times do |index|
      return finished(:halted) if @halted&.call

      @turns_taken = index + 1
      last = @turns_taken == @turns
      message = spoke(transcript, last: last)
      requested = Array(message["tool_calls"])

      if requested.blank? && !last && (pushed = pressed)
        transcript.said(message)
        transcript.closing(pushed)
        @analysis&.log_info("agent", "turn #{@turns_taken}", "pressed", pushed.truncate(200))
        next
      end

      return finished(:answered, message["content"]) if requested.blank? || last

      transcript.said(message)
      requested.each { |raw| answer(transcript, raw) }

      return finished(:flailed) if @flailed >= FLAILING
    end

    finished(:ran_out)
  end

  def inference_key = @inference&.key
  def offered_names = @offered.map(&:tool_name)

  private

    def spoke(transcript, last:)
      transcript.closing(LAST_TURN) if last

      @inference.converse(
        messages: transcript.messages,
        tools: last ? [] : declared,
        analysis: @analysis,
        turn: @turns_taken
      )
    end

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

    def pressed
      return nil if @unfinished.nil?

      pushed = @unfinished.call(@calls).presence
      return nil if pushed.nil? || @pressed.include?(pushed)

      @pressed << pushed
      pushed
    end

    def answer(transcript, raw)
      result = dispatch.call(raw)

      @calls << result
      @flailed = result.ok ? 0 : @flailed + 1

      note(result)
      transcript.answered(raw, result.content)
    end

    def dispatch
      @dispatch ||= Dispatch.new(offered: @offered, context: context)
    end

    def note(result)
      return if @analysis.nil?

      asked = result.arguments.to_h.to_json.truncate(200)

      if result.ok
        @analysis.log_done("agent", "turn #{@turns_taken}", result.name, asked)
      else
        @analysis.log_fail("agent", "turn #{@turns_taken}", result.name, asked, result.error)
      end
    end

    def finished(reason, said = nil)
      Answer.new(said: said.to_s.presence, reason: reason, turns: @turns_taken, calls: @calls)
    end

    def context
      { tenant_id: @grant.tenant.id, scopes: @grant.scopes }
    end
end
