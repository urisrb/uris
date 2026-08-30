class HomeController < ApplicationController
  def index
    return redirect_to setup_path unless current_tenant.paired?

    render html: "", layout: true
  end
end
