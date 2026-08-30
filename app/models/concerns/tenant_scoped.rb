module TenantScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :tenant, default: -> { Current.tenant }

    default_scope { where(tenant_id: Current.tenant&.id) }
  end
end
