class UploadsController < ApplicationController
  include Granted

  class Unusable < StandardError; end

  MAX_KEY = 900

  def create
    destination = Resource.default_storage

    return unusable("no default storage is set — pick one on Resources") if destination.nil?

    file = params[:file]

    return unusable("no file was sent") unless file.respond_to?(:original_filename)

    key = storage_key(params[:path].presence || file.original_filename)
    locator = destination.upload(key, file.tempfile)
    reference = Reference.discover!(
      resource: destination,
      locator: locator,
      locator_key: key,
      kind: Kind.for_filename(key),
      title: File.basename(key)
    )

    run = AnalyzeItemJob.start!(current_tenant.id, reference.item_id)

    render json: {
      item_id: reference.item_id,
      kind: reference.item.kind,
      resource: destination.key,
      path: key,
      run_id: run.id
    }
  rescue Unusable => e
    unusable(e.message)
  rescue Resource::Failed => e
    render json: { error: e.message }, status: :bad_gateway
  end

  private

    def authorize
      super && grant.permit!("items:catalog:write")
    rescue Grant::Denied => e
      refuse(Masks::Client::Unauthorized.new(e.message))
    end

    def unusable(message)
      render json: { error: message }, status: :unprocessable_entity
    end

    def storage_key(given)
      segments = given.to_s.tr("\\", "/").split("/").filter_map do |segment|
        cleaned = segment.gsub(/[[:cntrl:]]/, "").strip
        cleaned unless cleaned.empty? || cleaned == "." || cleaned == ".."
      end

      raise Unusable, "#{given} is not a usable path" if segments.empty?

      key = segments.join("/")

      raise Unusable, "that path is too long" if key.bytesize > MAX_KEY

      key
    end
end
