class ContentController < ApplicationController
  include Granted

  CHUNK = 64.kilobytes

  def show
    reference = find_reference or return head :not_found

    response.headers["Content-Type"] = reference.content_type
    response.headers["Content-Disposition"] =
      ActionDispatch::Http::ContentDisposition.format(
        disposition: params[:download] ? "attachment" : "inline",
        filename: reference.filename
      )

    stream(reference.download)
  rescue Resource::Failed => e
    render plain: e.message, status: :bad_gateway
  end

  def thumbnail
    reference = find_reference or return head :not_found

    send_data Thumbnail.for(reference, size: params[:size] || Thumbnail::DEFAULT_SIZE),
              type: Thumbnail::CONTENT_TYPE, disposition: "inline"
  rescue Thumbnail::Unavailable, Resource::Failed
    head :not_found
  end

  private

    def authorize
      super && grant.permit!("things:catalog:read")
    rescue Grant::Denied => e
      refuse(Masks::Client::Unauthorized.new(e.message))
    end

    def find_reference
      ThingReference.find_by(id: params[:id])
    end

    # The bytes are somewhere else and may be large, so hand them out as they
    # arrive rather than holding a whole object in memory to serve one image.
    def stream(io)
      self.response_body = Enumerator.new do |yielder|
        while (chunk = io.read(CHUNK))
          yielder << chunk
        end
      ensure
        io.close if io.respond_to?(:close)
      end
    end
end
