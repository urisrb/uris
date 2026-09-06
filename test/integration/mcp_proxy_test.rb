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

  def attach
    Tenant.switch(@tenant) do
      Resource::Mcp.create!(key: "exa", name: "Exa", credentials: { "token" => "sk-test" },
                            details: { "url" => "https://example.com/mcp", "tools" => LISTED })
    end
  end

  test "a proxied tool is listed under the resource's key" do
    attach

    listed = call(@tenant, ALL, "tools/list").dig("result", "tools").map { |tool| tool["name"] }

    assert_includes listed, "exa__web_search"
    assert_includes listed, "search_items"
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
