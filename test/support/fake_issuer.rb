require "socket"

class FakeIssuer
  ALGORITHM = "RS256".freeze

  class << self
    def current
      @current ||= new
    end

    def template
      "#{current.origin}/%{subdomain}"
    end
  end

  attr_reader :port

  def initialize
    @keys = {}
    @lock = Mutex.new
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @thread = Thread.new { serve }
  end

  def origin
    "http://127.0.0.1:#{port}"
  end

  def url_for(subdomain)
    "#{origin}/#{subdomain}"
  end

  def key_for(subdomain)
    @lock.synchronize do
      @keys[subdomain] ||= { key: OpenSSL::PKey::RSA.generate(2048), kid: SecureRandom.uuid }
    end
  end

  def mint(subdomain:, subject: "test", scopes: [], audience:, expires_in: 1.hour,
           tenant: nil, **extra)
    held = key_for(subdomain)

    JWT.encode({
      "iss" => url_for(subdomain),
      "sub" => subject,
      "aud" => audience,
      "exp" => expires_in.from_now.to_i,
      "iat" => Time.current.to_i,
      "jti" => SecureRandom.uuid,
      "scope" => Array(scopes).join(" "),
      "tenant" => tenant || { "uuid" => SecureRandom.uuid, "subdomain" => subdomain }
    }.merge(extra).compact, held[:key], ALGORITHM, { kid: held[:kid] })
  end

  private

    def serve
      loop do
        socket = @server.accept
        Thread.new { respond(socket) }
      end
    rescue IOError, Errno::EBADF
      nil
    end

    def respond(socket)
      line = socket.gets.to_s
      while (header = socket.gets) && header.strip != ""
      end

      found = body_for(line.split(" ")[1].to_s)
      body = JSON.generate(found || { "error" => "not_found" })

      socket.print [
        "HTTP/1.1 #{found ? '200 OK' : '404 Not Found'}",
        "Content-Type: application/json",
        "Content-Length: #{body.bytesize}",
        "Connection: close",
        "", body
      ].join("\r\n")
    rescue Errno::EPIPE, IOError
      nil
    ensure
      socket.close rescue nil
    end

    def body_for(path)
      case path
      when %r{\A/([^/]+)/\.well-known/openid-configuration\z} then discovery($1)
      when %r{\A/([^/]+)/\.well-known/jwks\.json\z} then jwks($1)
      end
    end

    def discovery(subdomain)
      url = url_for(subdomain)

      {
        "issuer" => url,
        "authorization_endpoint" => "#{url}/authorize",
        "token_endpoint" => "#{url}/token",
        "userinfo_endpoint" => "#{url}/userinfo",
        "jwks_uri" => "#{url}/.well-known/jwks.json",
        "registration_endpoint" => "#{url}/register",
        "revocation_endpoint" => "#{url}/revoke",
        "tenant" => { "subdomain" => subdomain }
      }
    end

    def jwks(subdomain)
      held = key_for(subdomain)

      { "keys" => [ JWT::JWK.new(held[:key], { kid: held[:kid], use: "sig", alg: ALGORITHM }).export ] }
    end
end
