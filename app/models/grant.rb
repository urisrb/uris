class Grant
  class Denied < StandardError; end

  SCOPES = %w[things:read things:write resources:read resources:command].freeze

  attr_reader :tenant, :subject, :scopes, :expires_at

  class << self
    def from_authorization(header, tenant:, audience:)
      token = header.to_s[/\ABearer (\S+)\z/, 1]
      raise Denied, "a bearer token is required" if token.nil?

      new(tenant: tenant, claims: Issuer.for(tenant).decode(token, audience: audience))
    rescue JWT::DecodeError => e
      raise Denied, e.message
    end
  end

  def initialize(tenant:, claims:)
    @tenant = tenant
    @subject = claims["sub"]
    @scopes = claims["scope"].to_s.split & SCOPES
    @expires_at = Time.zone.at(claims["exp"]) if claims["exp"]

    verify_tenant!(claims["tenant"])
  end

  def permits?(scope)
    scopes.include?(scope.to_s)
  end

  def permit!(scope)
    raise Denied, "this token does not carry #{scope}" unless permits?(scope)

    true
  end

  def tools
    Tool.all.select { |tool| permits?(tool.scope) }
  end

  private

    def verify_tenant!(claimed)
      subdomain = claimed.is_a?(Hash) ? claimed["subdomain"] : nil
      return if subdomain.blank? || subdomain == tenant.subdomain

      raise Denied, "this token was issued for #{subdomain}, not #{tenant.subdomain}"
    end
end
