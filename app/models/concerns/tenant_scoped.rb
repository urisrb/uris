# Included by every model that holds tenant data. The default scope is the
# primary enforcement — RLS exists to catch the day someone forgets this.
module TenantScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :tenant, default: -> { Current.tenant }

    default_scope { where(tenant_id: Current.tenant&.id) }
  end
end
