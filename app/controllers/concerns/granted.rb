module Granted
  extend ActiveSupport::Concern
  include Masks::Rails::ProtectedResource

  included do
    before_action :authorize
  end

  private

    def grant
      @grant ||= Grant.new(tenant: current_tenant, claims: masks_claims_from(credentials))
    end

    def authorize
      grant
    rescue Grant::Denied => e
      refuse(Masks::Client::Unauthorized.new(e.message))
    rescue Masks::Client::Challenge => e
      refuse(e)
    rescue Tenant::Unconfigured, Masks::Client::Unreachable => e
      unavailable(e)
    end

    def masks_claims_from(authorization)
      masks_resource.authenticate(authorization)
    end

    # The browser never holds a token: masks-rails keeps it in the encrypted
    # session, and it is verified here exactly as a presented one would be, so
    # a cookie and a bearer arrive at the same Grant by the same path.
    def credentials
      request.authorization.presence || session_authorization
    end

    def session_authorization
      return nil unless masks_signed_in? || (masks_tokens && masks_refresh!)

      "Bearer #{masks_access_token}"
    end

    def presented?
      request.authorization.present?
    end

    def refuse(error)
      presented? ? masks_challenge(error) : masks_refuse_json

      false
    end

    def unavailable(error)
      render json: {
        error: "server_error",
        error_description: error.message
      }, status: :service_unavailable

      false
    end
end
