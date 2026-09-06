class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  private

    def current_tenant
      Current.tenant
    end
end
