module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :tenant

    def connect
      self.tenant = Tenant.resolve(request.host) || reject_unauthorized_connection
    end
  end
end
