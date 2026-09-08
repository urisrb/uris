require "test_helper"

class ResourceMcpTest < ActiveSupport::TestCase
  LISTED = [
    { "name" => "web_search", "description" => "Search the web",
      "input_schema" => { "properties" => { "query" => { "type" => "string" } },
                          "required" => [ "query" ] } }
  ].freeze

  setup do
    @tenant = Tenant.create!(subdomain: "mcp-#{SecureRandom.hex(4)}", name: "Servers")
  end

  def server(**details)
    Tenant.switch(@tenant) do
      Resource::Mcp.create!(
        key: "exa", name: "Exa",
        details: { "url" => "https://example.com/mcp" }.merge(details),
        credentials: { "token" => "sk-test" }
      )
    end
  end

  def discovered
    server(**{ "tools" => LISTED })
  end

  test "a server with no address cannot be reached, so it is refused" do
    Tenant.switch(@tenant) do
      assert_not Resource::Mcp.new(key: "exa").valid?
    end
  end

  test "a key that could not prefix a tool name is refused" do
    Tenant.switch(@tenant) do
      held = Resource::Mcp.new(key: "Not A Key", details: { "url" => "https://a.test/mcp" })

      assert_not held.valid?
      assert_match(/prefix a tool/, held.errors.full_messages.join)
    end
  end

  test "a server pointing back at uris is refused rather than left to call itself" do
    with_suffix("uris.localhost") do
      Tenant.switch(@tenant) do
        held = Resource::Mcp.new(key: "loop", details: { "url" => "https://demo.uris.localhost/mcp" })

        assert_not held.valid?
        assert_match(/points back at uris/, held.errors.full_messages.join)
      end
    end
  end

  test "its tools are offered under its own key, so two servers cannot collide" do
    Tenant.switch(@tenant) do
      proxied = discovered.proxied_tools

      assert_equal 1, proxied.size
      assert_equal "exa__web_search", proxied.first.tool_name
      assert_equal Resource::Mcp::SCOPE, proxied.first.scope
      assert_equal "Search the web", proxied.first.description
      assert_equal({ "query" => { "type" => "string" } },
                   proxied.first.input_schema.to_h.deep_stringify_keys["properties"])
    end
  end

  test "a server that has never been checked offers nothing rather than guessing" do
    Tenant.switch(@tenant) { assert_empty server.proxied_tools }
  end

  test "a grant carrying the scope is offered the proxied tools alongside the built-in ones" do
    discovered

    offered = Tenant.switch(@tenant) { grant(Grant::SCOPES).tools.map(&:tool_name) }

    assert_includes offered, "exa__web_search"
    assert_includes offered, "search"
  end

  test "a grant without the scope is offered none of them" do
    discovered

    offered = Tenant.switch(@tenant) { grant([ "uris:catalog:read" ]).tools.map(&:tool_name) }

    assert_not_includes offered, "exa__web_search"
  end

  test "a private address is blocked before any tool is called" do
    Tenant.switch(@tenant) do
      inside = server(**{ "url" => "http://127.0.0.1:9200/mcp", "tools" => LISTED })

      assert_raises(PublicFetch::Blocked) { inside.invoke!("web_search", { query: "x" }) }
    end
  end

  private

    def grant(scopes)
      Grant.new(tenant: @tenant,
                claims: Masks::Client::Claims.new("sub" => "t", "scope" => scopes.join(" ")))
    end

    def with_suffix(suffix)
      previous = ENV["URIS_HOST_SUFFIX"]
      ENV["URIS_HOST_SUFFIX"] = suffix
      yield
    ensure
      ENV["URIS_HOST_SUFFIX"] = previous
    end
end
