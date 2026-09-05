require "net/http"
require "json"

class Resource
  class OpenaiCompatible < Resource
    DEFAULT_ROLE = "default"
    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 120
    MAX_TOKENS = 1024
    TEMPERATURE = 0.2
    JSON_ATTEMPTS = 3
    MAX_PROMPT = 40_000
    JSON_SYSTEM = "Respond with valid JSON only. No markdown, no explanation."

    def self.capabilities
      [ :inference ]
    end

    def self.command_schema
      { models: {} }
    end

    def self.permitted_origins
      ENV.fetch("THINGS_INFERENCE_ORIGINS", "").split(",").filter_map do |entry|
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

      true
    end

    def summarize(prompt, role:, promptable: nil)
      model = model_for(role)
      last = nil

      JSON_ATTEMPTS.times do |index|
        answer = complete(prompt, model: model, role: role, promptable: promptable, attempt: index + 1)
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

      def complete(prompt, model:, role:, promptable:, attempt:)
        body = scrub(prompt).truncate(MAX_PROMPT)
        record = Prompt.open!(resource: self, role: role, model: model,
                              request: body, promptable: promptable, attempt: attempt)

        begin
          content = ask(body, model)
        rescue StandardError => e
          record.fail!(e)
          raise
        end

        record.finish!(content)
        content
      end

      def ask(body, model)
        messages = [
          { role: "system", content: JSON_SYSTEM },
          { role: "user", content: body }
        ]

        payload = { model: model, messages: messages, stream: false,
                    max_tokens: max_tokens, temperature: temperature }
        payload[:response_format] = { type: "json_object" } if json_mode?

        answered = post("/chat/completions", payload)
        content = answered.dig("choices", 0, "message", "content").to_s

        raise Resource::Unusable, "#{key}: #{model} answered with nothing" if content.blank?

        without_reasoning(content)
      end

      def without_reasoning(text)
        text.gsub(%r{<think>.*?</think>}m, "").strip
      end

      def scrub(text)
        text.to_s.dup.force_encoding(Encoding::UTF_8).scrub("?").delete("\u0000")
      end

      def get(path)
        answer(dial(path)) { |uri| Net::HTTP::Get.new(uri, headers) }
      end

      def post(path, body)
        answer(dial(path)) do |uri|
          request = Net::HTTP::Post.new(uri, headers)
          request.body = JSON.generate(body)
          request
        end
      end

      def headers
        base = { "Content-Type" => "application/json", "User-Agent" => "things" }
        token = credentials["api_key"].presence

        token ? base.merge("Authorization" => "Bearer #{token}") : base
      end

      def dial(path)
        uri = URI.parse("#{base_url.chomp('/')}/#{path.delete_prefix('/')}")
        raise Resource::Unusable, "#{key}: #{base_url} is not an http url" unless uri.is_a?(URI::HTTP)

        uri
      end

      def answer(uri, &build)
        response = exchange(uri, &build)

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

      def exchange(uri, &build)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                            open_timeout: OPEN_TIMEOUT, read_timeout: read_timeout) do |http|
          http.request(build.call(uri))
        end
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise Resource::Failed, "#{key}: #{uri.host} did not answer in #{read_timeout}s"
      rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError => e
        raise Resource::Failed, "#{key}: #{e.class} reaching #{uri.host}"
      end

      def permitted!(target)
        return target if via.present?

        allowed = self.class.permitted_origins

        if allowed.empty?
          raise Resource::Unusable,
                "#{key}: no inference origins are permitted — set THINGS_INFERENCE_ORIGINS"
        end

        uri = URI.parse(target.to_s)
        origin = "#{uri.scheme}://#{uri.host}:#{uri.port}"
        return target if allowed.include?(origin)

        raise Resource::Unusable, "#{key}: #{origin} is not one of THINGS_INFERENCE_ORIGINS"
      rescue URI::InvalidURIError
        raise Resource::Unusable, "#{key}: #{target} is not a url"
      end
  end
end
