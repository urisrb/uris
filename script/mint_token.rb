subdomain = ENV.fetch("MCP_TOKEN_SUBDOMAIN")
scopes = ENV["MCP_TOKEN_SCOPES"].to_s.split.presence || Grant::SCOPES

tenant = Tenant.find_by(subdomain: subdomain)
abort "no tenant '#{subdomain}' — bin/rails db:seed creates the development ones" if tenant.nil?

origin = ENV["THINGS_PUBLIC_ORIGIN"].presence ||
  "http://#{tenant.subdomain}.#{ENV.fetch('THINGS_HOST_SUFFIX', 'things.test')}:#{ENV.fetch('PORT', '4242')}"

token = Issuer.for(tenant).mint(
  subject: "#{tenant.subdomain}-developer", scopes: scopes, audience: "#{origin}/mcp"
)

warn "endpoint  #{origin}/mcp"
warn "scopes    #{scopes.join(' ')}"
warn ""
puts token
