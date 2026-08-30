module ProtectedResource
  extend ActiveSupport::Concern

  private

    def resource_origin
      ENV["THINGS_PUBLIC_ORIGIN"].presence || request.base_url
    end

    def resource_url
      "#{resource_origin}/mcp"
    end

    def resource_metadata_url
      "#{resource_origin}/.well-known/oauth-protected-resource"
    end

    def challenge(description)
      response.headers["WWW-Authenticate"] = [
        "Bearer error=\"invalid_token\"",
        "error_description=\"#{description.tr('"', "'")}\"",
        "resource_metadata=\"#{resource_metadata_url}\"",
        "scope=\"#{Grant::SCOPES.join(' ')}\""
      ].join(", ")

      render json: { error: "invalid_token", error_description: description },
             status: :unauthorized
    end
end
