module Delegations
  CALLBACK_PATH = "/connect/callback".freeze

  Refused = Masks::Client::Delegations::Refused
  Unavailable = Masks::Client::Delegations::Unavailable

  mattr_accessor :fake

  class << self
    def for(tenant, origin: nil)
      return fake if fake

      raise Tenant::Unconfigured, "#{tenant.subdomain} has not shaken hands with masks, so nothing can be connected" unless tenant.connected?

      Masks::Client::Delegations.new(
        issuer: tenant.issuer,
        client_id: tenant.client_id,
        client_secret: tenant.client_secret,
        redirect_uri: "#{origin || tenant.origin}#{CALLBACK_PATH}"
      )
    end
  end
end
