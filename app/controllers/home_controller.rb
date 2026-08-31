class HomeController < ApplicationController
  def index
    return redirect_to masks.handshake_path unless current_tenant.connected?

    render html: "", layout: true
  end
end
