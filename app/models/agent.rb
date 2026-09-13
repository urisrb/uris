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

  WROTE_A_CALL = <<~TEXT.squish.freeze
    You wrote a tool call out as text instead of making it, so nothing ran. Make the call with the
    tool itself, then answer from what it returns.
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
    @clock = Clock.new(analysis)
  end

  def call(prompt)
    raise Refused, "no inference resource serves the agent role" if @inference.nil?

    transcript = Transcript.new(system: [ SYSTEM, @clock.told ].compact.join("\n"), prompt: prompt)

    @turns.times do |index|
      return finished(:halted) if @halted&.call

      @turns_taken = index + 1
      last = @turns_taken == @turns || @clock.closing?
      message = spoke(transcript, last: last)
      requested = Array(message["tool_calls"])

      if requested.blank? && !last && (pushed = pressed(message))
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
      told = @offered.map do |tool|
        {
          type: "function",
          function: {
            name: tool.tool_name,
            description: tool.description.to_s.strip,
            parameters: tool.input_schema.to_h
          }
        }
      end

      @clock.declared + told
    end

    def pressed(message)
      wanted = [ (WROTE_A_CALL if wrote_a_call?(message["content"])), @unfinished&.call(@calls).presence ]
      pushed = wanted.compact.find { |held| !@pressed.include?(held) }
      return nil if pushed.nil?

      @pressed << pushed
      pushed
    end

    def wrote_a_call?(content)
      held = Resource::OpenaiCompatible.extract_json(content.to_s.gsub(%r{<think>.*?</think>}m, ""))
      return false unless held.is_a?(Hash)

      named = (held["name"] || held.dig("function", "name")).to_s
      return true if offered_names.include?(named) || named == Clock::NAME

      held.key?("do") && (held.key?("key") || held.key?("id"))
    end

    def answer(transcript, raw)
      result = @clock.handles?(raw) ? @clock.call(raw) : dispatch.call(raw)

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
