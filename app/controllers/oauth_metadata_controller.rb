class OauthMetadataController < ApplicationController
  include Masks::Rails::ProtectedResource

  def protected_resource
    render json: masks_resource_metadata
  rescue Tenant::Unconfigured, Masks::Client::Error => e
    render json: { error: "server_error", error_description: e.message },
           status: :service_unavailable
  end
end
