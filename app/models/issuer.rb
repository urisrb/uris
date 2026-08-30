require "net/http"

class Issuer
  class Unconfigured < StandardError; end

  ALGORITHMS = %w[RS256 ES256].freeze
  DEV_ALGORITHM = "HS256"
  JWKS_TTL = 5.minutes

  attr_reader :tenant

  def self.for(tenant)
    new(tenant)
  end

  def initialize(tenant)
    @tenant = tenant
  end

  def url
    template = ENV["MASKS_ISSUER_TEMPLATE"].presence
    raise Unconfigured, "MASKS_ISSUER_TEMPLATE is not set" if template.nil?

    format(template, subdomain: tenant.subdomain)
  end

  def decode(token, audience:)
    claims = {
      iss: url, verify_iss: true,
      aud: audience, verify_aud: true,
      verify_expiration: true, required_claims: %w[iss aud sub exp]
    }

    if dev_secret
      JWT.decode(token, dev_secret, true, algorithms: [ DEV_ALGORITHM ], **claims).first
    else
      JWT.decode(token, nil, true, algorithms: ALGORITHMS, jwks: keys, **claims).first
    end
  end

  def mint(subject:, scopes:, audience:, expires_in: 1.hour)
    unless dev_secret
      raise Unconfigured, "MASKS_DEV_SECRET is not set — real tokens come from masks"
    end

    JWT.encode({
      iss: url, aud: audience, sub: subject,
      scope: Array(scopes).join(" "),
      iat: Time.current.to_i, exp: expires_in.from_now.to_i
    }, dev_secret, DEV_ALGORITHM)
  end

  private

    def dev_secret
      return nil unless Rails.env.local?

      ENV["MASKS_DEV_SECRET"].presence
    end

    def keys
      ->(options) do
        Rails.cache.delete(cache_key("jwks")) if options[:invalidate]

        Rails.cache.fetch(cache_key("jwks"), expires_in: JWKS_TTL) { fetch(jwks_uri) }
      end
    end

    def jwks_uri
      document = Rails.cache.fetch(cache_key("discovery"), expires_in: JWKS_TTL) do
        fetch(URI.join("#{url}/", ".well-known/openid-configuration"))
      end

      unless document["issuer"] == url
        raise Unconfigured, "the discovery document names #{document['issuer'].inspect}, not #{url}"
      end

      document["jwks_uri"].presence ||
        raise(Unconfigured, "the issuer publishes no jwks_uri")
    end

    def cache_key(part)
      "issuer/#{part}/#{url}"
    end

    def fetch(uri)
      response = Net::HTTP.get_response(URI(uri))

      unless response.is_a?(Net::HTTPSuccess)
        raise Unconfigured, "#{uri} answered HTTP #{response.code}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError
      raise Unconfigured, "#{uri} did not answer JSON"
    rescue SystemCallError, SocketError, Net::OpenTimeout => e
      raise Unconfigured, "the issuer is unreachable (#{e.class})"
    end
end
