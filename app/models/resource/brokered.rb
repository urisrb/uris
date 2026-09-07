class Resource
  module Brokered
    extend ActiveSupport::Concern

    SKEW = 30.seconds

    class_methods do
      def brokered?
        true
      end
    end

    def brokered?
      true
    end

    def connection_id
      credentials["connection_id"].presence ||
        raise(Resource::Failed, "#{key} names no connection — enrol it before using it")
    end

    def connection_id=(value)
      self.credentials = credentials.merge("connection_id" => value.to_s)
    end

    def upstream_token
      return @upstream_token if defined?(@upstream_token) && @upstream_token

      @upstream_token = Broker.release(connection_id)
    end

    def forget_upstream_token
      remove_instance_variable(:@upstream_token) if defined?(@upstream_token)
    end

    def token
      upstream_token
    end

    def token_expired!
      forget_upstream_token

      true
    end
  end
end
