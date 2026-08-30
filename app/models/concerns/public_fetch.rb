require "net/http"
require "resolv"
require "ipaddr"

module PublicFetch
  extend ActiveSupport::Concern

  class Blocked < Resource::Failed; end

  MAX_BYTES = 5.megabytes
  MAX_REDIRECTS = 3
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 15

  class_methods do
    def private_fetches_allowed?
      ENV["THINGS_ALLOW_PRIVATE_FETCH"].present?
    end
  end

  private

    def permitted!(target)
      uri = URI.parse(target.to_s)

      unless uri.is_a?(URI::HTTP) && uri.host.present?
        raise Blocked, "#{key}: #{target} is not an http or https URL"
      end

      return uri if self.class.private_fetches_allowed?

      addresses(uri.host).each do |address|
        if address.loopback? || address.private? || address.link_local?
          raise Blocked, "#{key}: #{uri.host} resolves to #{address}, which is not a public address"
        end
      end

      uri
    end

    def addresses(host)
      Resolv.getaddresses(host).filter_map do |found|
        IPAddr.new(found) rescue nil
      end.presence || raise(Resource::Failed, "#{key}: #{host} does not resolve")
    end

    def over_http(target, redirects: MAX_REDIRECTS, &build)
      uri = permitted!(target)
      response = exchange(uri, &build)

      case response
      when Net::HTTPRedirection
        raise Resource::Failed, "#{key}: too many redirects from #{target}" if redirects.zero?

        over_http(URI.join(uri, response["location"].to_s).to_s, redirects: redirects - 1, &build)
      when Net::HTTPSuccess
        response
      else
        raise Resource::Failed, "#{key}: #{target} answered #{response.code}"
      end
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, SystemCallError, OpenSSL::SSL::SSLError => e
      raise Resource::Failed, "#{key}: #{e.class} fetching #{target}"
    end

    def exchange(uri, &build)
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                      open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        http.request(build.call(uri))
      end
    end

    def bounded(response)
      body = response.body.to_s
      raise Resource::Failed, "#{key}: more than #{MAX_BYTES} bytes" if body.bytesize > MAX_BYTES

      body
    end
end
