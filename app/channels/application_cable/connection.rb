module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :tenant

    # The tenant comes from the host, exactly as it does for HTTP requests.
    # Resolving it once here means no channel can be reached without one.
    def connect
      self.tenant = Tenant.resolve(request.host) || reject_unauthorized_connection
    end
  end
end
