require "webmock/minitest"
require "resolv"

WebMock.disable_net_connect!(allow_localhost: true)

WebMock.globally_stub_request(:after_local_stubs) do |request|
  next if WebMock::Util::URI.is_uri_localhost?(request.uri)

  raise Errno::ECONNREFUSED, request.uri.host.to_s
end

module Offline
  PUBLIC = "93.184.215.14".freeze
  LOOPBACK = "127.0.0.1".freeze
  RESERVED_TLD = ".invalid".freeze

  def getaddresses(host)
    held = host.to_s

    return [] if held.end_with?(RESERVED_TLD)
    return [ LOOPBACK ] if held == "localhost"

    [ PUBLIC ]
  end
end

Resolv.singleton_class.prepend(Offline)
