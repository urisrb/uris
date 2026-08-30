Rails.application.config.to_prepare do
  Masks::Rails.configure do |config|
    config.issuer = ->(request) { Tenant.issuer_url(request) }
    config.resource = ->(request) { Tenant.resource_url(request) }
    config.client_id = ->(_) { ENV["MASKS_CLIENT_ID"] }
    config.client_secret = ->(_) { ENV["MASKS_CLIENT_SECRET"].presence }
    config.resource_scopes = Grant::SCOPES
    config.scope = %w[openid profile email offline_access] + Grant::SCOPES
    config.after_sign_in = "/"
    config.after_sign_out = "/"
  end
end
