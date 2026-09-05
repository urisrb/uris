class Grant
  class Denied < StandardError; end

  DESCRIBED = {
    "uris:catalog:read" => "Search your catalog and read what is in it",
    "uris:catalog:write" => "Add to your catalog, and run analysis over it",
    "uris:resources:read" => "List the places your items live",
    "uris:resources:command" => "Act on those places — sync, fetch, and export",
    "uris:settings:read" => "Read how you have set uris up for yourself",
    "uris:settings:write" => "Change how uris behaves for you",
    "uris:settings:admin" => "Change how uris behaves for everyone here"
  }.freeze

  NAMESPACE = "uris:".freeze

  SCOPES = DESCRIBED.keys.freeze

  ADMINISTRATIVE = %w[uris:settings:admin].freeze

  SIGN_IN = (SCOPES - ADMINISTRATIVE).freeze

  attr_reader :tenant, :claims

  def initialize(tenant:, claims:)
    @tenant = tenant
    @claims = claims

    verify_tenant!
  end

  def subject
    claims.subject
  end

  def scopes
    @scopes ||= claims.scopes & SCOPES
  end

  def expires_at
    claims.expires_at
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

    def verify_tenant!
      claimed = claims.tenant
      return if claimed.subdomain.blank? || claimed.subdomain == tenant.subdomain

      raise Denied, "this token was issued for #{claimed.subdomain}, not #{tenant.subdomain}"
    end
end
