class Tenant < ApplicationRecord
  class Unconfigured < StandardError; end

  has_many :things, dependent: :destroy
  has_many :resources, dependent: :destroy

  validates :subdomain, presence: true, uniqueness: true,
                        format: { with: /\A[a-z0-9][a-z0-9-]*\z/ }
  validates :name, presence: true

  after_create_commit { SearchIndex.create_alias!(self) }

  class << self
    def resolve(host)
      find_by(subdomain: host.to_s.split(".").first)
    end

    def origin(request)
      ENV["THINGS_PUBLIC_ORIGIN"].presence || request.base_url
    end

    def resource_url(request)
      "#{origin(request)}/mcp"
    end

    def issuer_url(request)
      template = ENV["MASKS_ISSUER_TEMPLATE"].presence
      raise Unconfigured, "MASKS_ISSUER_TEMPLATE is not set" if template.nil?

      format(template, subdomain: request.host.to_s.split(".").first)
    end

    def switch(tenant)
      raise ArgumentError, "no tenant" if tenant.nil?

      previous_tenant = Current.tenant

      ActiveRecord::Base.transaction(requires_new: true) do
        previous_setting = tenant_setting
        assign_tenant_setting(tenant.id)
        Current.tenant = tenant

        begin
          yield tenant
        ensure
          Current.tenant = previous_tenant
          assign_tenant_setting(previous_setting)
        end
      end
    end

    private

      def tenant_setting
        connection.select_value("SELECT current_setting('things.tenant_id', true)")
      end

      def assign_tenant_setting(id)
        connection.exec_query(
          "SELECT set_config('things.tenant_id', $1, true)", "tenant", [ id.to_s ]
        )
      rescue ActiveRecord::StatementInvalid
        nil
      end
  end
end
