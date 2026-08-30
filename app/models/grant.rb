class Grant
  class Denied < StandardError; end

  DESCRIBED = {
    "things:read" => "Search your catalog and read what is in it",
    "things:write" => "Add to your catalog, and run analysis over it",
    "resources:read" => "List the places your things live",
    "resources:command" => "Act on those places — sync, fetch, and export"
  }.freeze

  SCOPES = DESCRIBED.keys.freeze

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
