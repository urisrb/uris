require "webmock/minitest"

WebMock.disable_net_connect!(allow_localhost: true)

WebMock.globally_stub_request(:after_local_stubs) do |request|
  next if WebMock::Util::URI.is_uri_localhost?(request.uri)

  raise Errno::ECONNREFUSED, request.uri.host.to_s
end
