class SetupController < ApplicationController
  include Masks::Rails::Authentication

  STATE = :pairing_state

  SCOPES = (%w[openid profile email offline_access] + Grant::SCOPES).freeze

  layout "plain"

  before_action :require_unpaired_or_signed_in

  def show
  end

  def create
    state = SecureRandom.urlsafe_base64(32)
    session[STATE] = state

    redirect_to connect_url(state), allow_other_host: true
  rescue Tenant::Unconfigured => e
    refuse("unconfigured", e.message)
  end

  def callback
    return refuse(params[:error], params[:error_description]) if params[:error].present?
    return refuse("invalid_state", "the callback did not match this browser") unless state_matches?
    return refuse("invalid_issuer", "that came back from somewhere else") unless issuer_matches?

    current_tenant.pair!(redeem)
    session.delete(STATE)

    redirect_to Masks::Rails::Engine.routes.url_helpers.start_path
  rescue Masks::Client::Error => e
    refuse(e.class.name.demodulize.underscore, e.message)
  end

  private

    def require_unpaired_or_signed_in
      return unless current_tenant.paired?
      return if masks_signed_in?

      redirect_to root_path
    end

    def redeem
      Masks::Client::Pairing.redeem(
        issuer_url,
        token: params[:initial_access_token],
        name: name,
        redirect_uris: [ Tenant.redirect_url(request) ],
        grant_types: %w[authorization_code refresh_token],
        scope: SCOPES,
        token_endpoint_auth_method: "client_secret_basic"
      )
    end

    def connect_url(state)
      Masks::Client::Pairing.url(
        issuer_url,
        name: name,
        resource: Tenant.resource_url(request),
        redirect_uris: [ Tenant.redirect_url(request) ],
        scope: SCOPES,
        return_to: "#{Tenant.origin(request)}#{setup_callback_path}",
        state: state
      )
    end

    def name
      Rails.application.class.module_parent_name
    end

    def issuer_url
      @issuer_url ||= Tenant.issuer_url(request)
    end

    def state_matches?
      held = session[STATE]

      held.present? &&
        ActiveSupport::SecurityUtils.secure_compare(held, params[:state].to_s)
    end

    def issuer_matches?
      params[:iss].blank? || params[:iss] == issuer_url
    end

    def refuse(code, description)
      session.delete(STATE)

      @code = code
      @description = description

      render :refused, status: :bad_request
    end
end
