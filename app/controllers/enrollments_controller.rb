class EnrollmentsController < ApplicationController
  include Granted

  rescue_from Enrollment::Invalid, with: :not_valid

  def show
    enrollment = redeem!

    redirect_to "#{Current.issuer}/connections/#{enrollment.provider}/start?#{URI.encode_www_form(
      return_to: "#{Current.origin}/enroll/#{params[:token]}/done"
    )}", allow_other_host: true
  end

  def done
    enrollment = redeem!

    return failed(params[:error_description].presence || params[:error]) if params[:error].present?
    return failed("no connection came back from the broker") if params[:connection].blank?

    resource = enrollment.claim!(params[:connection])

    AuditEvent.record(
      channel: "enrollment", action: "claim", status: "ok", scope: "resources:command",
      grant: Current.grant, context: Current.audit,
      arguments: { type: resource.class.sti_name, key: resource.key }
    )

    redirect_to "/resources/#{resource.id}", allow_other_host: false
  end

  private

    def authorize
      super && grant.permit!("resources:command")
    rescue Grant::Denied => e
      refuse(Masks::Client::Unauthorized.new(e.message))
    end

    def redeem!
      enrollment = Enrollment.redeem(params[:token])

      raise Enrollment::Invalid, "that enrollment belongs to another tenant" unless
        enrollment.belongs_to?(current_tenant)

      enrollment
    end

    def not_valid(error)
      render plain: error.message, status: :bad_request
    end

    def failed(description)
      render plain: "enrollment did not complete: #{description}", status: :bad_gateway
    end
end
