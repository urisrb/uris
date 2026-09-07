module Tenancy
  module Job
    extend ActiveSupport::Concern

    KEY = "tenant".freeze
    EVERY = "*".freeze

    class Homeless < StandardError
      def initialize(job)
        super(
          "#{job} was reached outside any tenant. A job carries the tenant it was enqueued in so " \
          "that it reads the same rows the request did; without one it would perform against " \
          "whichever tenant its worker thread happened to hold last. Enqueue it inside " \
          "Tenant.switch, or declare across_tenants! on it if it is maintenance meant to span " \
          "every tenant."
        )
      end
    end

    included do
      class_attribute :across_tenants, instance_accessor: false, default: false
    end

    class_methods do
      def across_tenants!
        self.across_tenants = true
      end
    end

    def initialize(...)
      super

      @tenant_held = Current.tenant&.subdomain
    end

    def serialize
      super.merge(KEY => enqueued_in)
    end

    def deserialize(job_data)
      super

      @tenant_carried = true
      @tenant_held = job_data[KEY]
    end

    def perform_now
      within_tenant { super }
    end

    def within_tenant(&block)
      return yield if self.class.across_tenants || @tenant_held == EVERY

      raise Homeless, self.class.name if @tenant_held.blank? && @tenant_carried

      tenant = held_tenant || argued_tenant

      return yield if tenant.nil?

      Tenant.switch(tenant, &block)
    end

    def held_tenant
      @tenant_held.presence && Tenant.find_by!(subdomain: @tenant_held)
    end

    private

      def argued_tenant
        held = arguments.first

        Tenant.find_by(id: held) if held.is_a?(Integer)
      end

      def enqueued_in
        return EVERY if self.class.across_tenants

        @tenant_held || Current.tenant&.subdomain || raise(Homeless, self.class.name)
      end
  end
end
