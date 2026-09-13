require "test_helper"

class McpProxyTest < ActionDispatch::IntegrationTest
  include McpClient

  ALL = Grant::SCOPES
  LISTED = [
    { "name" => "web_search", "description" => "Search the web",
      "input_schema" => { "properties" => { "query" => { "type" => "string" } },
                          "required" => [ "query" ] } }
  ].freeze

  setup do
    SearchIndex.reset!
    Rails.cache.clear
    McpTransports.reset!

    @tenant = Tenant.create!(subdomain: "prx-#{SecureRandom.hex(4)}", name: "Proxied")
  end

  def attach(auth: "bearer", credentials: { "token" => "sk-test" }, **details)
    Tenant.switch(@tenant) do
      Resource::Mcp.create!(key: "exa", name: "Exa", credentials: credentials,
                            details: { "url" => "https://example.com/mcp", "tools" => LISTED, "auth" => auth,
                                       **details.transform_keys(&:to_s) })
    end
  end

  test "a proxied tool is listed under the resource's key" do
    attach

    listed = call(@tenant, ALL, "tools/list").dig("result", "tools").map { |tool| tool["name"] }

    assert_includes listed, "exa__web_search"
    assert_includes listed, "search"
  end

  test "the server is dialled at the address it was vetted at, not wherever its name points next" do
    attach
    speaks(text: "pinned")
    dialled = []
    recorder = Module.new do
      define_method(:request) do |*args, **options, &block|
        dialled << instance_variable_get(:@ipaddr) if address == "example.com"
        super(*args, **options, &block)
      end
    end
    Net::HTTP.prepend(recorder)

    call(@tenant, ALL, "tools/call", name: "exa__web_search", arguments: { query: "x" })

    assert_equal [ Offline::PUBLIC ], dialled.uniq
  ensure
    recorder&.send(:define_method, :request) { |*args, **options, &block| super(*args, **options, &block) }
  end

  test "a bearer token is sent as one" do
    attach
    speaks(text: "ok")

    tool(@tenant, ALL, "exa__web_search", query: "anything")

    assert_requested(:post, "https://example.com/mcp", headers: { "Authorization" => "Bearer sk-test" }, at_least_times: 1)
  end

  test "a server behind basic auth is sent the username and password on every request" do
    attach(auth: "basic", credentials: { "username" => "reader", "password" => "pa:ss" })
    speaks(text: "behind the gate")

    found = tool(@tenant, ALL, "exa__web_search", query: "anything")

    assert_equal [ "behind the gate" ], found["content"]
    assert_requested(:post, "https://example.com/mcp",
                     headers: { "Authorization" => "Basic #{Base64.strict_encode64('reader:pa:ss')}" }, at_least_times: 2)
    assert_not_requested(:post, "https://example.com/mcp", headers: { "Authorization" => "Bearer sk-test" })
  end

  test "a server that wants a header of its own is sent that header and no Authorization" do
    attach(auth: "header", credentials: { "header_value" => "key-123" }, header_name: "X-API-Key")
    speaks(text: "keyed")

    tool(@tenant, ALL, "exa__web_search", query: "anything")

    assert_requested(:post, "https://example.com/mcp", headers: { "X-API-Key" => "key-123" }, at_least_times: 2)
    assert_not_requested(:post, "https://example.com/mcp") { |request| request.headers.key?("Authorization") }
  end

  test "calling it forwards to the server and hands back what it said" do
    attach
    speaks(text: "a page about anything")

    found = tool(@tenant, ALL, "exa__web_search", query: "anything")

    assert_equal [ "a page about anything" ], found["content"]
  end

  test "a server that answers an error says so on the call, not on the tool list" do
    attach
    speaks(text: "upstream is down", failed: true)

    reply = call(@tenant, ALL, "tools/call",
                 name: "exa__web_search", arguments: { query: "anything" })

    assert reply.dig("result", "isError")
    assert_match(/upstream is down/, reply.dig("result", "content", 0, "text"))
  end

  test "a server that will not answer at all is a failure, not a hang" do
    attach
    stub_request(:post, "https://example.com/mcp").to_return(status: 502, body: "nope")

    reply = call(@tenant, ALL, "tools/call",
                 name: "exa__web_search", arguments: { query: "anything" })

    assert reply.dig("result", "isError")
  end

  test "attaching a server changes what tools/list answers rather than serving a stale one" do
    before = call(@tenant, ALL, "tools/list").dig("result", "tools").map { |tool| tool["name"] }

    assert_not_includes before, "exa__web_search"

    attach
    @mcp_sessions = nil

    after = call(@tenant, ALL, "tools/list").dig("result", "tools").map { |tool| tool["name"] }

    assert_includes after, "exa__web_search"
  end

  test "a token without the scope is not offered another server's tools" do
    attach

    listed = call(@tenant, [ "uris:catalog:read" ], "tools/list")
             .dig("result", "tools").map { |tool| tool["name"] }

    assert_not_includes listed, "exa__web_search"
  end

  private

    def speaks(text:, failed: false)
      stub_request(:post, "https://example.com/mcp").to_return do |request|
        asked = JSON.parse(request.body)

        { status: 200, headers: { "Content-Type" => "application/json" },
          body: replied(asked, text, failed).to_json }
      end
    end

    def replied(asked, text, failed)
      base = { jsonrpc: "2.0", id: asked["id"] }

      case asked["method"]
      when "initialize"
        base.merge(result: { protocolVersion: "2025-06-18", capabilities: { tools: {} },
                             serverInfo: { name: "exa", version: "1" } })
      when "tools/call"
        base.merge(result: { content: [ { type: "text", text: text } ], isError: failed })
      else
        base.merge(result: {})
      end
    end
end
