class Agent
  class Transcript
    RESULT_BUDGET = 8_000
    REPLAYED = %w[role content tool_calls].freeze

    def initialize(system:, prompt:)
      @messages = [
        { "role" => "system", "content" => system.to_s },
        { "role" => "user", "content" => prompt.to_s }
      ]
    end

    def messages
      @messages.map(&:dup)
    end

    def said(message)
      held = message.to_h.transform_keys(&:to_s).slice(*REPLAYED)
      held["content"] = held["content"].to_s

      @messages << held
    end

    def answered(raw, content)
      @messages << {
        "role" => "tool",
        "tool_call_id" => raw.to_h["id"].to_s,
        "name" => raw.to_h.dig("function", "name").to_s,
        "content" => bounded(content)
      }
    end

    def closing(text)
      @messages << { "role" => "user", "content" => text.to_s }
    end

    private

      def bounded(content)
        held = content.to_s

        return held if held.length <= RESULT_BUDGET

        "#{held.first(RESULT_BUDGET)}\n\n[cut — #{held.length - RESULT_BUDGET} more characters. " \
          "Narrow the request if you need the rest.]"
      end
  end
end
