require "test_helper"

class McpEndpointTest < ActionDispatch::IntegrationTest
  ALL = Grant::SCOPES

  setup do
    SearchIndex.reset!

    @tenant = Tenant.create!(subdomain: "mcp-#{SecureRandom.hex(4)}", name: "Endpoint")
    @other = Tenant.create!(subdomain: "mcp-#{SecureRandom.hex(4)}", name: "Elsewhere")

    Tenant.switch(@tenant) do
      @resource = Resource::S3.create!(key: "endpoint-bucket", name: "Bucket",
                                       details: { "endpoint" => "http://127.0.0.1:1" })
      @thing = create_thing(kind: "pdf", title: "March invoice", locator_key: "invoices/march.pdf",
                            resource: @resource, locator: { "bucket" => "endpoint-bucket" })
    end

    Tenant.switch(@other) do
      @theirs = create_thing(kind: "pdf", title: "Their invoice", locator_key: "invoices/theirs.pdf")
    end

    SearchIndex.refresh!
  end

  test "an unauthenticated call answers with the challenge that starts the OAuth flow" do
    post "/mcp", headers: host_for(@tenant), params: rpc("initialize"), as: :json

    assert_response :unauthorized

    challenge = response.headers["WWW-Authenticate"]

    assert_match(/\ABearer /, challenge)
    assert_includes challenge, %(resource_metadata="#{origin_for(@tenant)}/.well-known/oauth-protected-resource")
    assert_includes challenge, %(scope="#{ALL.join(' ')}")
  end

  test "the metadata the challenge points at names this tenant's issuer" do
    get "/.well-known/oauth-protected-resource", headers: host_for(@tenant)

    assert_response :success

    metadata = response.parsed_body

    assert_equal "#{origin_for(@tenant)}/mcp", metadata["resource"]
    assert_equal [ Issuer.for(@tenant).url ], metadata["authorization_servers"]
    assert_equal ALL, metadata["scopes_supported"]
  end

  test "a token minted for one tenant is refused by another" do
    post "/mcp", headers: host_for(@other).merge(bearer(@tenant, ALL)),
                 params: rpc("tools/list"), as: :json

    assert_response :unauthorized
  end

  test "an expired token is refused" do
    travel_to 2.hours.ago do
      @stale = bearer(@tenant, ALL)
    end

    post "/mcp", headers: host_for(@tenant).merge(@stale), params: rpc("tools/list"), as: :json

    assert_response :unauthorized
  end

  test "the token decides which tools exist at all" do
    names = call(@tenant, [ "things:read" ], "tools/list").dig("result", "tools").map { |t| t["name"] }

    assert_equal %w[search_things get_thing], names
  end

  test "a tool outside the grant is not callable, not merely unlisted" do
    reply = call(@tenant, [ "things:read" ], "tools/call",
                 name: "sync_resource", arguments: { id: @resource.id.to_s })

    assert_nil reply["result"]
    assert_match(/Tool not found/, reply.dig("error", "data"))
  end

  test "search returns this tenant's things and never another's" do
    result = tool(@tenant, ALL, "search_things", query: "invoice")

    assert_equal [ @thing.id.to_s ], result["things"].map { |t| t["id"] }
  end

  test "a thing belonging to another tenant cannot be fetched by id" do
    reply = call(@tenant, ALL, "tools/call",
                 name: "get_thing", arguments: { id: @theirs.id.to_s })

    assert reply.dig("result", "isError")
    assert_match(/no thing/, reply.dig("result", "content", 0, "text"))
  end

  test "describe_resource advertises the vocabulary command_resource accepts" do
    described = tool(@tenant, ALL, "describe_resource", id: @resource.id.to_s)

    assert_equal "s3", described["type"]
    assert_includes described["commands"].keys, "list"
    assert_not_includes described.to_json, "secret_access_key"
  end

  test "an unknown command is refused before the adapter is reached" do
    reply = call(@tenant, ALL, "tools/call", name: "command_resource",
                 arguments: { id: @resource.id.to_s, command: "rm", arguments: {} })

    assert reply.dig("result", "isError")
    assert_match(/no command 'rm'/, reply.dig("result", "content", 0, "text"))
  end

  test "sync queues a run against the named resource" do
    assert_enqueued_with(job: SyncResourceJob, args: [ @tenant.id, @resource.id ]) do
      result = tool(@tenant, ALL, "sync_resource", id: @resource.id.to_s)

      assert result["queued"]
    end
  end

  test "check_resource answers with the failure instead of becoming one" do
    checked = tool(@tenant, ALL, "check_resource", id: @resource.id.to_s)

    assert_not checked["ok"]
    assert_not_nil checked["checked_at"]
    assert_not_nil checked["error"]
  end

  test "a resource carries what its last check found" do
    tool(@tenant, ALL, "check_resource", id: @resource.id.to_s)

    listed = tool(@tenant, ALL, "list_resources")["resources"].first

    assert_not_nil listed["checked_at"]
    assert_not_nil listed["check_error"]
  end

  test "export refuses a destination that is not storage" do
    reply = call(@tenant, ALL, "tools/call", name: "export_things",
                 arguments: { destination_id: "0" })

    assert reply.dig("result", "isError")
  end

  private

    def origin_for(tenant)
      "http://#{tenant.subdomain}.things.test"
    end

    def host_for(tenant)
      { "HOST" => "#{tenant.subdomain}.things.test" }
    end

    def bearer(tenant, scopes)
      token = Issuer.for(tenant).mint(
        subject: "test", scopes: scopes, audience: "#{origin_for(tenant)}/mcp"
      )

      { "Authorization" => "Bearer #{token}" }
    end

    def rpc(method, params = nil)
      { jsonrpc: "2.0", id: SecureRandom.uuid, method: method, params: params }.compact
    end

    def call(tenant, scopes, method, **params)
      post "/mcp", headers: host_for(tenant).merge(bearer(tenant, scopes)),
                   params: rpc(method, params.presence), as: :json

      assert_response :success
      response.parsed_body
    end

    def tool(tenant, scopes, name, **arguments)
      reply = call(tenant, scopes, "tools/call", name: name, arguments: arguments)

      assert_not reply.dig("result", "isError"), reply.dig("result", "content", 0, "text")

      JSON.parse(reply.dig("result", "content", 0, "text"))
    end
end
