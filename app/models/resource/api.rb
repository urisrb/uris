require "net/http"
require "json"

class Resource
  class Api < Resource
    class Gone < Resource::Failed; end

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 30
    MAX_BYTES = 8.megabytes
    MAX_TEXT = 100_000
    PAGE = 100
    RETRY_AFTER = 60

    class << self
      def api
        raise NotImplementedError, "#{name} names no API"
      end

      def service
        name.demodulize
      end

      def token_field(label, help: nil, placeholder: nil)
        field("token", label, required: true, secret: true, help: help, placeholder: placeholder)
      end
    end

    def token
      return upstream_token if brokered?

      credentials["token"].presence ||
        raise(Resource::Unusable, "#{key} carries no token — attach it again")
    end

    def api_get(path, **query)
      answer(:get, path, query: query)
    end

    def api_post(path, body, **query)
      answer(:post, path, query: query, body: body)
    end

    def api_text(path, **query)
      answer(:get, path, query: query, raw: true)
    end

    private

      def headers
        {
          "Authorization" => "Bearer #{token}",
          "Accept" => "application/json",
          "User-Agent" => "uris"
        }
      end

      def endpoint(path, query)
        base = path.start_with?("http") ? path : "#{self.class.api}#{path}"
        wanted = query.compact
        uri = URI.parse(wanted.empty? ? base : "#{base}#{base.include?('?') ? '&' : '?'}#{URI.encode_www_form(wanted)}")

        unless uri.is_a?(URI::HTTPS) && uri.host == URI.parse(self.class.api).host
          raise Resource::Unusable, "#{key}: #{uri} is not #{self.class.service}"
        end

        uri
      end

      def answer(verb, path, query: {}, body: nil, raw: false, retried: false)
        uri = endpoint(path, query)
        response = exchange(uri, verb, body)

        case response
        when Net::HTTPUnauthorized
          return retry_once(verb, path, query, body, raw) if brokered? && !retried

          raise Resource::Unusable, "#{key}: #{self.class.service} refused the token"
        when Net::HTTPNotFound
          raise Gone, "#{key}: #{self.class.service} has no #{uri.path}"
        when Net::HTTPTooManyRequests, Net::HTTPForbidden
          raise Resource::Failed, "#{key}: #{self.class.service} is rate limiting — #{refused(response)}"
        when Net::HTTPServerError
          raise Resource::Failed, "#{key}: #{self.class.service} answered #{response.code}"
        when Net::HTTPSuccess
          raw ? bounded(response) : parsed(response)
        else
          raise Resource::Unusable, "#{key}: #{self.class.service} answered #{response.code} — #{refused(response)}"
        end
      end

      def retry_once(verb, path, query, body, raw)
        forget_upstream_token

        answer(verb, path, query: query, body: body, raw: raw, retried: true)
      end

      def parsed(response)
        JSON.parse(bounded(response).presence || "{}")
      rescue JSON::ParserError
        raise Resource::Failed, "#{key}: #{self.class.service} did not answer with JSON"
      end

      def bounded(response)
        held = response.body.to_s

        raise Resource::Failed, "#{key}: more than #{MAX_BYTES} bytes" if held.bytesize > MAX_BYTES

        held
      end

      def refused(response)
        body = JSON.parse(response.body.to_s[0, 4096])
        [ body["message"], body["error"], body.dig("error", "message") ]
          .find { |said| said.is_a?(String) && said.present? } || "no reason given"
      rescue JSON::ParserError
        response.body.to_s.squish.truncate(120).presence || "no reason given"
      end

      def exchange(uri, verb, body)
        Net::HTTP.start(uri.hostname, uri.port, use_ssl: true,
                        open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
          http.request(built(uri, verb, body))
        end
      rescue Net::OpenTimeout, Net::ReadTimeout
        raise Resource::Failed, "#{key}: #{uri.host} did not answer in #{READ_TIMEOUT}s"
      rescue Net::HTTPBadResponse, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
        raise Resource::Failed, "#{key}: #{e.class} reaching #{uri.host}"
      end

      def built(uri, verb, body)
        return Net::HTTP::Get.new(uri, headers) if verb == :get

        Net::HTTP::Post.new(uri, headers.merge("Content-Type" => "application/json")).tap do |request|
          request.body = JSON.generate(body || {})
        end
      end

      def flattened(*parts)
        parts.flatten.compact_blank.join("\n\n").strip.truncate(MAX_TEXT)
      end
  end
end
