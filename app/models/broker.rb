class Broker
  class Error < Resource::Failed; end
  class Unauthorized < Error; end
  class Unreachable < Error; end

  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10
  LIMIT = 64.kilobytes

  class << self
    def release(connection_id, issuer: nil, credentials: nil)
      resolved = issuer || Current.issuer

      raise Error, "no issuer is known for this request" if resolved.blank?

      new(issuer: resolved, credentials: credentials || Current.credentials).release(connection_id)
    end
  end

  attr_reader :issuer, :credentials

  def initialize(issuer:, credentials:)
    @issuer = issuer.to_s.chomp("/")
    @credentials = credentials
  end

  def release(connection_id)
    raise Unauthorized, "this request carries no token to release a connection with" if credentials.blank?

    body = post("#{issuer}/connections/token", connection_id: connection_id)

    body.fetch("access_token") { raise Error, "the broker returned no access token" }
  end

  private

    def post(url, **params)
      uri = URI.parse(url)

      request = Net::HTTP::Post.new(uri, "Accept" => "application/json", "Authorization" => credentials)
      request.set_form_data(params.transform_keys(&:to_s))

      response = Net::HTTP.start(
        uri.hostname, uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: OPEN_TIMEOUT,
        read_timeout: READ_TIMEOUT
      ) { |http| http.request(request) }

      interpret(response)
    rescue Net::HTTPBadResponse, Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError,
           OpenSSL::SSL::SSLError, URI::InvalidURIError => e
      raise Unreachable, "the credential broker did not answer: #{e.class}"
    end

    def interpret(response)
      body = parse(response.body)

      return body if response.is_a?(Net::HTTPSuccess)

      described = [ body["error"], body["error_description"] ].compact.join(": ")
      described = "the broker answered #{response.code}" if described.blank?

      raise Unauthorized, described if response.is_a?(Net::HTTPUnauthorized) || response.is_a?(Net::HTTPForbidden)

      raise Error, described
    end

    def parse(body)
      parsed = JSON.parse(body.to_s[0, LIMIT])
      parsed.is_a?(Hash) ? parsed : {}
    rescue JSON::ParserError
      {}
    end
end
