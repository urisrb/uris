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
        Rails.cache.delete(cache_key) if options[:invalidate]
        Rails.cache.fetch(cache_key, expires_in: JWKS_TTL) { fetch_keys }
      end
    end

    def cache_key
      "issuer/jwks/#{url}"
    end

    def fetch_keys
      response = Net::HTTP.get_response(URI.join("#{url}/", ".well-known/jwks.json"))

      unless response.is_a?(Net::HTTPSuccess)
        raise Unconfigured, "the issuer published no keys (HTTP #{response.code})"
      end

      JSON.parse(response.body)
    rescue SystemCallError, SocketError, Net::OpenTimeout => e
      raise Unconfigured, "the issuer is unreachable (#{e.class})"
    end
end
