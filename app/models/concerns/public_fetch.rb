require "net/http"

module PublicFetch
  extend ActiveSupport::Concern

  class Blocked < Resource::Failed; end

  MAX_BYTES = 5.megabytes
  MAX_REDIRECTS = 3
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15
  CARRIED_TO_ANOTHER_ORIGIN = %w[accept accept-encoding accept-language content-type depth user-agent].freeze

  class_methods do
    def private_fetches_allowed?
      PublicAddress.allowed?
    end
  end

  private

    def permitted!(target)
      PublicAddress.permitted!(target, allow_private: self.class.private_fetches_allowed?)
    rescue PublicAddress::Blocked => e
      raise Blocked, "#{key}: #{e.message}"
    rescue PublicAddress::Unresolvable => e
      raise Resource::Failed, "#{key}: #{e.message}"
    end

    def pinned!(target)
      PublicAddress.pinned!(target, allow_private: self.class.private_fetches_allowed?)
    rescue PublicAddress::Blocked => e
      raise Blocked, "#{key}: #{e.message}"
    rescue PublicAddress::Unresolvable => e
      raise Resource::Failed, "#{key}: #{e.message}"
    end

    def over_http(target, redirects: MAX_REDIRECTS, origin: nil, &build)
      pinned = pinned!(target)
      uri = pinned.uri
      origin ||= origin_of(uri)
      response = exchange(pinned) { |at| confined(build.call(at), at, origin) }

      case response
      when Net::HTTPRedirection
        raise Resource::Failed, "#{key}: too many redirects from #{target}" if redirects.zero?

        over_http(URI.join(uri, response["location"].to_s).to_s,
                  redirects: redirects - 1, origin: origin, &build)
      when Net::HTTPSuccess
        response
      else
        raise Resource::Failed, "#{key}: #{target} answered #{response.code}"
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
      raise Resource::Failed, "#{key}: #{e.class} fetching #{target}"
    end

    def confined(request, at, origin)
      return request if origin_of(at) == origin

      request.to_hash.each_key do |name|
        request.delete(name) unless CARRIED_TO_ANOTHER_ORIGIN.include?(name)
      end

      request
    end

    def origin_of(uri)
      [ uri.scheme, uri.hostname.to_s.downcase, uri.port ]
    end

    def exchange(pinned, &build)
      PublicAddress.start(pinned, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(build.call(pinned.uri))
      end
    end

    def bounded(response)
      body = response.body.to_s
      raise Resource::Failed, "#{key}: more than #{MAX_BYTES} bytes" if body.bytesize > MAX_BYTES

      body
    end
end
