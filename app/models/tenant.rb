class Tenant < ApplicationRecord
  class Unconfigured < Masks::Client::Error; end

  encrypts :client_secret
  encrypts :registration_access_token

  has_many :items, dependent: :destroy
  has_many :resources, dependent: :destroy

  validates :subdomain, presence: true, uniqueness: true,
                        format: { with: /\A[a-z0-9][a-z0-9-]*\z/ }
  validates :name, presence: true

  after_create_commit { SearchIndex.create_alias!(self) }

  def connected?
    client_id.present? && client_secret.present?
  end

  def masks_credentials
    return nil unless connected?

    {
      client_id: client_id,
      client_secret: client_secret,
      registration_access_token: registration_access_token,
      registration_client_uri: registration_client_uri
    }
  end

  def disconnect!
    update!(
      client_id: nil, client_secret: nil,
      registration_access_token: nil, registration_client_uri: nil,
      connected_at: nil
    )
  end

  def connect!(registration)
    update!(
      client_id: registration.client_id,
      client_secret: registration.client_secret,
      registration_access_token: registration.access_token,
      registration_client_uri: registration.uri,
      connected_at: Time.current
    )
  end

  class << self
    def resolve(host)
      find_by(subdomain: subdomain_in(host))
    end

    def subdomain_in(host)
      host.to_s.split(".").first
    end

    def resolve!(host)
      resolve(host) || raise(Unconfigured, "no tenant is served at #{host}")
    end

    def origin(request)
      override = ENV["URIS_PUBLIC_ORIGIN"].presence
      return request.base_url if override.nil?

      format(override, subdomain: subdomain_in(request.host))
    end

    def resource_url(request)
      "#{origin(request)}/mcp"
    end

    def issuer_url(request)
      template = ENV["MASKS_ISSUER_TEMPLATE"].presence
      raise Unconfigured, "MASKS_ISSUER_TEMPLATE is not set" if template.nil?

      format(template, subdomain: subdomain_in(request.host))
    end

    def redirect_url(request)
      "#{origin(request)}#{Masks::Rails::Engine.routes.url_helpers.callback_path}"
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
        connection.select_value("SELECT current_setting('uris.tenant_id', true)")
      end

      def assign_tenant_setting(id)
        connection.exec_query(
          "SELECT set_config('uris.tenant_id', $1, true)", "tenant", [ id.to_s ]
        )
      rescue ActiveRecord::StatementInvalid
        nil
      end
  end
end
