# Serves the SPA shell. Every non-API route lands here and React takes over.
class HomeController < ApplicationController
  def index
    render html: "", layout: true
  end
end
