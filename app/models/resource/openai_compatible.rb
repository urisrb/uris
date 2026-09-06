require "net/http"
require "json"

class Resource
  class OpenaiCompatible < Resource
    DEFAULT_ROLE = "default"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 120
    VISION_TIMEOUT = 600
    MAX_TOKENS = 1024
    TEMPERATURE = 0.2
    JSON_ATTEMPTS = 3
    MAX_PROMPT = 40_000
    MAX_IMAGE = 8.megabytes
    IMAGE_TYPE = "image/jpeg"
    JSON_SYSTEM = "Respond with valid JSON only. No markdown, no explanation."
    AGENT_ROLE = "agent"
    CHAIN_TIMEOUT = 120
    CHAIN_SYSTEM = "You have tools. Call one rather than answering from memory."
    CHAIN_ASK = "Search the catalog for invoices, then tell me what you found."
    CHAIN_RESULT = { count: 1, items: [ { id: "itm_1", title: "acme.pdf" } ] }.to_json
    CHAIN_TOOL = {
      type: "function",
      function: {
        name: "search_items",
        description: "Search the catalog.",
        parameters: {
          type: "object",
          properties: { query: { type: "string", description: "Words to match." } },
          required: [ "query" ]
        }
      }
    }.freeze

    def self.capabilities
      [ :inference ]
    end

    def self.command_schema
      { models: {} }
    end

    def self.permitted_origins
      ENV.fetch("URIS_INFERENCE_ORIGINS", "").split(",").filter_map do |entry|
        next if entry.strip.blank?

        begin
          uri = URI.parse(entry.strip)
          "#{uri.scheme}://#{uri.host}:#{uri.port}" if uri.is_a?(URI::HTTP)
        rescue URI::InvalidURIError
          nil
        end
      end
    end

    validate :it_names_an_endpoint

    def models
      details.fetch("models", {})
    end

    def serves_role?(role)
      models.key?(role.to_s) || models.key?(DEFAULT_ROLE)
    end

    def model_for(role)
      models[role.to_s] || models[DEFAULT_ROLE] ||
        raise(Resource::Unusable, "#{key} serves no model for #{role}")
    end

    def read_timeout = details.fetch("read_timeout", READ_TIMEOUT).to_i
    def vision_timeout = details.fetch("read_timeout", VISION_TIMEOUT).to_i
    def max_tokens = details.fetch("max_tokens", MAX_TOKENS).to_i
    def temperature = details.fetch("temperature", TEMPERATURE).to_f
    def json_mode? = details.fetch("json_mode", true)

    def base_url
      permitted!(via.present? ? via.reach!(configured_url) : configured_url)
    end

    def check!
      served = model_names
      wanted = models.values.uniq
      missing = wanted - served

      if wanted.empty?
        raise Resource::Unusable, "#{key}: no models are declared — set details.models"
      end

      if missing.any?
        raise Resource::Unusable,
              "#{key}: #{base_url} does not serve #{missing.join(', ')} — it serves #{served.first(8).join(', ').presence || 'nothing'}"
      end

      chains! if models.key?(AGENT_ROLE)

      true
    end

    # Serving a model is not the same as being able to drive a tool loop. Two turns,
    # because one proves nothing: a model can answer the first call correctly and then
    # break the moment a tool result is in the history, which is every turn after it.
    #
    # A floor rather than a ceiling. One synthetic tool catches a model that cannot call
    # tools at all, which is the categorical failure. It will not catch one that degrades
    # against the real eleven — bin/probe-agent measures that, and the adapter stays out
    # of the tool registry.
    def chains!
      model = model_for(AGENT_ROLE)
      messages = [ { role: "system", content: CHAIN_SYSTEM }, { role: "user", content: CHAIN_ASK } ]

      first = turn(model, messages)
      call = first["tool_calls"]&.first

      unless call
        raise Resource::Unusable,
              "#{key}: #{model} serves the #{AGENT_ROLE} role but answered without a tool call — " \
              "#{first['content'].to_s.squish.truncate(120)}"
      end

      messages << first
      messages << { role: "tool", tool_call_id: call["id"].to_s, name: CHAIN_TOOL.dig(:function, :name),
                    content: CHAIN_RESULT }

      second = turn(model, messages)
      return true if second["tool_calls"].present?

      said = second["content"].to_s.squish
      return true unless said.include?('"name"') || said.start_with?("[{", "{\"")

      raise Resource::Unusable,
            "#{key}: #{model} wrote its second call as text instead of a tool call, so it " \
            "cannot drive a loop — #{said.truncate(120)}"
    end

    def summarize(prompt, role:, promptable: nil, images: [])
      model = model_for(role)
      last = nil

      JSON_ATTEMPTS.times do |index|
        answer = complete(prompt, model: model, role: role, promptable: promptable,
                          attempt: index + 1, images: images)
        parsed = self.class.extract_json(answer)

        return parsed if parsed.is_a?(Hash) && parsed.present?

        last = answer
      end

      raise Resource::Unusable,
            "#{key}: #{model} did not answer with JSON in #{JSON_ATTEMPTS} tries — #{last.to_s.truncate(200)}"
    end

    def command_models
      { "base_url" => base_url, "declared" => models, "available" => model_names }
    end

    def self.extract_json(text)
      body = text.to_s
      fenced = body[/```(?:json)?\s*(\{.*?\})\s*```/m, 1]

      ([ fenced ].compact + objects(body)).each do |candidate|
        parsed = begin
          JSON.parse(candidate)
        rescue JSON::ParserError
          nil
        end

        return parsed if parsed.is_a?(Hash)
      end

      nil
    end

    def self.objects(body)
      found = []
      depth = 0
      start = nil
      quoted = false
      escaped = false

      body.each_char.with_index do |char, index|
        if quoted
          if escaped then escaped = false
          elsif char == "\\" then escaped = true
          elsif char == '"' then quoted = false
          end
          next
        end

        case char
        when '"' then quoted = true
        when "{"
          start = index if depth.zero?
          depth += 1
        when "}"
          next if depth.zero?

          depth -= 1
          found << body[start..index] if depth.zero?
        end
      end

      found
    end

    private

      def configured_url = details["base_url"].to_s

      def it_names_an_endpoint
        errors.add(:details, "must name a base_url") if details["base_url"].blank?
      end

      def model_names
        get("/models").fetch("data", []).filter_map { |entry| entry["id"] }
      end

      def complete(prompt, model:, role:, promptable:, attempt:, images:)
        body = scrub(prompt).truncate(MAX_PROMPT)
        record = Prompt.open!(resource: self, role: role, model: model,
                              request: body, promptable: promptable, attempt: attempt)

        begin
          content = ask(body, model, images)
        rescue StandardError => e
          record.fail!(e)
          raise
        end

        record.finish!(content)
        content
      end

      def ask(body, model, images)
        messages = [
          { role: "system", content: JSON_SYSTEM },
          { role: "user", content: said(body, images) }
        ]

        payload = { model: model, messages: messages, stream: false,
                    max_tokens: max_tokens, temperature: temperature }
        payload[:response_format] = { type: "json_object" } if json_mode?

        answered = post("/chat/completions", payload,
                        timeout: images.any? ? vision_timeout : read_timeout)
        content = answered.dig("choices", 0, "message", "content").to_s

        raise Resource::Unusable, "#{key}: #{model} answered with nothing" if content.blank?

        without_reasoning(content)
      end

      def said(body, images)
        return body if images.empty?

        [ { type: "text", text: body } ] +
          images.map { |bytes| { type: "image_url", image_url: { url: data_uri(bytes) } } }
      end

      def data_uri(bytes)
        if bytes.bytesize > MAX_IMAGE
          raise Resource::Unusable,
                "#{key}: an image of #{bytes.bytesize} bytes is more than #{MAX_IMAGE} to send"
        end

        "data:#{IMAGE_TYPE};base64,#{Base64.strict_encode64(bytes)}"
      end

      def without_reasoning(text)
        text.gsub(%r{<think>.*?</think>}m, "").strip
      end

      def scrub(text)
        text.to_s.dup.force_encoding(Encoding::UTF_8).scrub("?").delete("\u0000")
      end

      def get(path)
        answer(dial(path), read_timeout) { |uri| Net::HTTP::Get.new(uri, headers) }
      end

      def turn(model, messages)
        answered = post("/chat/completions", {
          model: model, stream: false, max_tokens: max_tokens, temperature: temperature,
          messages: messages, tools: [ CHAIN_TOOL ]
        }, timeout: CHAIN_TIMEOUT)

        answered.dig("choices", 0, "message") || {}
      end

      def post(path, body, timeout: read_timeout)
        answer(dial(path), timeout) do |uri|
          request = Net::HTTP::Post.new(uri, headers)
          request.body = JSON.generate(body)
          request
        end
      end

      def headers
        base = { "Content-Type" => "application/json", "User-Agent" => "uris" }
        token = credentials["api_key"].presence

        token ? base.merge("Authorization" => "Bearer #{token}") : base
      end

      def dial(path)
        uri = URI.parse("#{base_url.chomp('/')}/#{path.delete_prefix('/')}")
        raise Resource::Unusable, "#{key}: #{base_url} is not an http url" unless uri.is_a?(URI::HTTP)

        uri
      end

      def answer(uri, timeout, &build)
        response = exchange(uri, timeout, &build)

        case response
        when Net::HTTPSuccess then JSON.parse(response.body.to_s)
        when Net::HTTPTooManyRequests then raise Resource::Failed, "#{key}: #{uri.host} is busy"
        when Net::HTTPServerError then raise Resource::Failed, "#{key}: #{uri.host} answered #{response.code}"
        else
          raise Resource::Unusable,
                "#{key}: #{uri.host} answered #{response.code} — #{response.body.to_s.truncate(200)}"
        end
      rescue JSON::ParserError
        raise Resource::Unusable, "#{key}: #{uri.host} did not answer with JSON"
      end

      def exchange(uri, timeout, &build)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                            open_timeout: OPEN_TIMEOUT, read_timeout: timeout) do |http|
          http.request(build.call(uri))
        end
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise Resource::Failed, "#{key}: #{uri.host} did not answer in #{timeout}s"
      rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError => e
        raise Resource::Failed, "#{key}: #{e.class} reaching #{uri.host}"
      end

      def permitted!(target)
        return target if via.present?

        allowed = self.class.permitted_origins

        if allowed.empty?
          raise Resource::Unusable,
                "#{key}: no inference origins are permitted — set URIS_INFERENCE_ORIGINS"
        end

        uri = URI.parse(target.to_s)
        origin = "#{uri.scheme}://#{uri.host}:#{uri.port}"
        return target if allowed.include?(origin)

        raise Resource::Unusable, "#{key}: #{origin} is not one of URIS_INFERENCE_ORIGINS"
      rescue URI::InvalidURIError
        raise Resource::Unusable, "#{key}: #{target} is not a url"
      end
  end
end
