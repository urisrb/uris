module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :tenant, :grant

    def connect
      self.tenant = Tenant.resolve(request.host) || reject_unauthorized_connection
      self.grant = Tenant.switch(tenant) { granted } || reject_unauthorized_connection
    end

    private

      def granted
        tokens = Masks::Client::Tokens.from_h(masks_session)
        return nil if tokens.nil? || tokens.access_token.blank? || tokens.expired?

        Grant.new(
          tenant: tenant,
          claims: resource.authenticate("Bearer #{tokens.access_token}")
        )
      rescue Masks::Client::Error, Grant::Denied, Tenant::Unconfigured
        nil
      end

      def masks_session
        session = cookies.encrypted[Rails.application.config.session_options[:key]]

        session.is_a?(Hash) ? session[Masks::Rails.config.session_key] : nil
      end

      def resource
        Masks::Rails.config.resource_server_for(request)
      end
  end
end
