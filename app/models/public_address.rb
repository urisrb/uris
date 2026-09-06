require "resolv"
require "ipaddr"

module PublicAddress
  class Blocked < StandardError; end
  class Unresolvable < StandardError; end

  SCHEMES = %w[http https].freeze

  RESERVED = %w[
    0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12
    192.0.0.0/24 192.0.2.0/24 192.88.99.0/24 192.168.0.0/16 198.18.0.0/15
    198.51.100.0/24 203.0.113.0/24 224.0.0.0/4 240.0.0.0/4
    ::/128 ::1/128 64:ff9b::/96 100::/64 2001:db8::/32 fc00::/7 fe80::/10 ff00::/8
  ].map { |block| IPAddr.new(block) }.freeze

  class << self
    def allowed?
      ENV["URIS_ALLOW_PRIVATE_FETCH"].present?
    end

    def permitted!(target, allow_private: allowed?)
      uri = parse(target)

      unless uri.is_a?(URI::HTTP) && uri.hostname.present?
        raise Blocked, "#{target} is not an http or https URL"
      end

      return uri if allow_private

      addresses(uri.hostname).each do |address|
        next unless reserved?(address)

        raise Blocked, "#{uri.hostname} resolves to #{address}, which is not a public address"
      end

      uri
    end

    def permitted?(target, allow_private: allowed?)
      permitted!(target, allow_private: allow_private)
      true
    rescue Blocked, Unresolvable
      false
    end

    # ::ffff:127.0.0.1 is loopback wearing an IPv6 costume, and every range test
    # below answers false until it is taken off.
    def reserved?(address)
      native = address.ipv4_mapped? ? address.native : address

      RESERVED.any? { |block| block.include?(native) }
    end

    def addresses(host)
      literal = numeric(host)
      return [ literal ] if literal

      found = Resolv.getaddresses(host).filter_map { |entry| numeric(entry) }
      raise Unresolvable, "#{host} does not resolve" if found.empty?

      found
    end

    private

      def parse(target)
        URI.parse(target.to_s)
      rescue URI::InvalidURIError
        raise Blocked, "#{target} is not a URL"
      end

      def numeric(value)
        IPAddr.new(value.to_s)
      rescue IPAddr::Error
        nil
      end
  end
end
