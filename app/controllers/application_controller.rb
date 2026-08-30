class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  around_action :with_tenant

  private

    # Tenants are addressed by subdomain. Resolving from the host — never from
    # the record being requested — is what keeps a cross-tenant read from
    # looking like an ordinary lookup.
    def current_tenant
      @current_tenant ||= Tenant.resolve(request.host)
    end

    def with_tenant
      return render_unknown_tenant if current_tenant.nil?

      Tenant.switch(current_tenant) { yield }
    end

    def render_unknown_tenant
      render plain: "Unknown tenant", status: :not_found
    end
end
