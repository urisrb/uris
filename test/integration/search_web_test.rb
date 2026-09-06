require "test_helper"

class SearchWebTest < ActionDispatch::IntegrationTest
  include McpClient

  ALL = Grant::SCOPES
  ANSWER = { results: [ { title: "A page", url: "https://example.test/a", text: "what it says" } ] }.freeze

  setup do
    SearchIndex.reset!
    Rails.cache.clear

    @tenant = Tenant.create!(subdomain: "web-#{SecureRandom.hex(4)}", name: "Searcher")
  end

  def attach_engine
    Tenant.switch(@tenant) do
      Resource::Search.create!(key: "exa", name: "Exa", details: { "provider" => "exa" },
                               credentials: { "api_key" => "sk-test" })
    end
  end

  def stub_exa(body = ANSWER)
    stub_request(:post, "https://api.exa.ai/search")
      .to_return(status: 200, headers: { "Content-Type" => "application/json" }, body: body.to_json)
  end

  test "the web is searched through the tenant's own engine" do
    attach_engine
    stub_exa

    found = tool(@tenant, ALL, "search_web", query: "anything")

    assert_equal 1, found["count"]
    assert_equal "https://example.test/a", found.dig("results", 0, "url")
  end

  test "a tenant with nothing to search with is told so rather than answering emptily" do
    reply = call(@tenant, ALL, "tools/call", name: "search_web", arguments: { query: "anything" })

    assert reply.dig("result", "isError")
    assert_match(/nothing that searches the web/, reply.dig("result", "content", 0, "text"))
  end

  test "a token without the web scope is not even offered the tool" do
    attach_engine
    stub_exa

    reply = call(@tenant, [ "uris:catalog:read" ], "tools/call",
                 name: "search_web", arguments: { query: "anything" })

    assert_match(/Tool not found/, reply.dig("error", "data").to_s)
  end

  test "the tool is offered only to a token that carries the scope" do
    assert_includes Tool.all, Tool::SearchWeb

    granted = ->(scopes) {
      Grant.new(tenant: @tenant,
                claims: Masks::Client::Claims.new("sub" => "t", "scope" => scopes.join(" ")))
        .tools.map(&:tool_name)
    }

    assert_includes granted.call(ALL), "search_web"
    assert_not_includes granted.call([ "uris:catalog:read" ]), "search_web"
  end

  test "an agent is offered the web alongside the catalog" do
    assert_includes Agent::READ_TOOLS, "search_web"
  end
end
