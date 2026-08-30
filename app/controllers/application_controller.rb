class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  around_action :with_tenant

  private

    def current_tenant
      @current_tenant ||= Tenant.resolve(request.host)
    end

    def with_tenant
      return render plain: "Unknown tenant", status: :not_found if current_tenant.nil?

      Tenant.switch(current_tenant) { yield }
    end
end
