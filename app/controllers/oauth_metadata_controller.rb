class OauthMetadataController < ApplicationController
  include ProtectedResource

  def protected_resource
    render json: {
      resource: resource_url,
      authorization_servers: [ Issuer.for(current_tenant).url ],
      scopes_supported: Grant::SCOPES,
      bearer_methods_supported: [ "header" ]
    }
  rescue Issuer::Unconfigured => e
    render json: { error: "server_error", error_description: e.message },
           status: :service_unavailable
  end
end
