class UploadsController < ApplicationController
  include Granted

  def create
    file = params[:file]

    return unusable("no file was sent") unless file.respond_to?(:original_filename)

    landed = Intake.write!(
      path: params[:path].presence || file.original_filename,
      body: file.tempfile
    )

    render json: {
      item_id: landed.item.id,
      kind: landed.item.kind,
      resource: landed.reference.resource.key,
      path: landed.reference.locator_key,
      run_id: landed.run.id
    }
  rescue Intake::Unusable => e
    unusable(e.message)
  rescue Resource::Failed => e
    render json: { error: e.message }, status: :bad_gateway
  end

  private

    def authorize
      super && grant.permit!("uris:catalog:write")
    rescue Grant::Denied => e
      refuse(Masks::Client::Unauthorized.new(e.message))
    end

    def unusable(message)
      render json: { error: message }, status: :unprocessable_entity
    end
end
