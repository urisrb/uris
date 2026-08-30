Rails.application.config.to_prepare do
  Masks::Rails.configure do |config|
    config.issuer = ->(request) { Tenant.issuer_url(request) }
    config.resource = ->(request) { Tenant.resource_url(request) }
    config.redirect_uri = ->(request) { Tenant.redirect_url(request) }
    config.client_id = ->(request) { Tenant.resolve(request.host)&.client_id }
    config.client_secret = ->(request) { Tenant.resolve(request.host)&.client_secret }
    config.resource_scopes = Grant::SCOPES
    config.scope = %w[openid profile email offline_access] + Grant::SCOPES
    config.after_sign_in = "/"
    config.after_sign_out = "/"
  end
end
