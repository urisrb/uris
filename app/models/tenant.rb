class Tenant < ApplicationRecord
  has_many :things, dependent: :destroy
  has_many :resources, dependent: :destroy

  validates :subdomain, presence: true, uniqueness: true,
                        format: { with: /\A[a-z0-9][a-z0-9-]*\z/ }
  validates :name, presence: true

  class << self
    def resolve(host)
      find_by(subdomain: host.to_s.split(".").first)
    end

    def switch(tenant)
      raise ArgumentError, "no tenant" if tenant.nil?

      previous = Current.tenant

      ActiveRecord::Base.transaction(requires_new: true) do
        assign_tenant_setting(tenant.id)
        Current.tenant = tenant

        begin
          yield tenant
        ensure
          Current.tenant = previous
          clear_tenant_setting
        end
      end
    end

    private

      def assign_tenant_setting(id)
        connection.exec_query(
          "SELECT set_config('things.tenant_id', $1, true)", "tenant", [ id.to_s ]
        )
      end

      def clear_tenant_setting
        connection.exec_query(
          "SELECT set_config('things.tenant_id', '', true)", "tenant", []
        )
      rescue ActiveRecord::StatementInvalid
        nil
      end
  end
end
