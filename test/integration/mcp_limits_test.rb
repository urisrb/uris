require "test_helper"

class McpLimitsTest < ActionDispatch::IntegrationTest
  ALL = Grant::SCOPES

  setup do
    Rails.cache.clear

    @tenant = Tenant.create!(subdomain: "limit-#{SecureRandom.hex(4)}", name: "Limited")
    @other = Tenant.create!(subdomain: "limit-#{SecureRandom.hex(4)}", name: "Elsewhere")

    Tenant.switch(@tenant) do
      @resource = Resource::S3.create!(key: "limited-bucket", name: "Bucket",
                                       details: { "endpoint" => "http://127.0.0.1:1" })
    end
  end

  def limit
    Rails.configuration.things.mcp_limit
  end

  def budget
    Rails.configuration.things.run_budget
  end

  test "a token is bounded at the edge, and the refusal is json-rpc shaped" do
    held = bearer(@tenant, ALL)

    limit.times { post "/mcp", headers: host_for(@tenant).merge(held), params: rpc("tools/list"), as: :json }

    assert_response :success

    post "/mcp", headers: host_for(@tenant).merge(held), params: rpc("tools/list"), as: :json

    assert_response :too_many_requests
    assert_equal(-32_000, response.parsed_body.dig("error", "code"))
  end

  test "the limiter is reached before the token is verified" do
    limit.times do
      post "/mcp", headers: host_for(@tenant).merge("Authorization" => "Bearer nonsense"),
                   params: rpc("tools/list"), as: :json
      assert_response :unauthorized
    end

    post "/mcp", headers: host_for(@tenant).merge("Authorization" => "Bearer nonsense"),
                 params: rpc("tools/list"), as: :json

    assert_response :too_many_requests
  end

  test "two tokens have two budgets" do
    spent = bearer(@tenant, ALL)

    limit.times { post "/mcp", headers: host_for(@tenant).merge(spent), params: rpc("tools/list"), as: :json }

    post "/mcp", headers: host_for(@tenant).merge(spent), params: rpc("tools/list"), as: :json
    assert_response :too_many_requests

    post "/mcp", headers: host_for(@tenant).merge(bearer(@tenant, ALL)),
                 params: rpc("tools/list"), as: :json
    assert_response :success
  end

  test "one tenant cannot exhaust another's edge budget" do
    limit.times do
      post "/mcp", headers: host_for(@tenant).merge("Authorization" => "Bearer nonsense"),
                   params: rpc("tools/list"), as: :json
    end

    post "/mcp", headers: host_for(@tenant).merge("Authorization" => "Bearer nonsense"),
                 params: rpc("tools/list"), as: :json
    assert_response :too_many_requests

    post "/mcp", headers: host_for(@other).merge("Authorization" => "Bearer nonsense"),
                 params: rpc("tools/list"), as: :json
    assert_response :unauthorized
  end

  test "starting runs is bounded far tighter than reading is" do
    held = bearer(@tenant, ALL)

    budget.times do
      reply = tools_call(held, "sync_resource", id: @resource.id.to_s)
      assert_not reply.dig("result", "isError"), reply.dig("result", "content", 0, "text")
    end

    reply = tools_call(held, "sync_resource", id: @resource.id.to_s)

    assert reply.dig("result", "isError")
    assert_match(/#{budget} is the ceiling/, reply.dig("result", "content", 0, "text"))
  end

  test "a tool that starts no run does not spend the run budget" do
    held = bearer(@tenant, ALL)

    (budget + 5).times { tools_call(held, "list_resources") }

    reply = tools_call(held, "sync_resource", id: @resource.id.to_s)

    assert_not reply.dig("result", "isError"), reply.dig("result", "content", 0, "text")
  end

  test "being over budget is recorded as denied rather than as an error" do
    held = bearer(@tenant, ALL)

    (budget + 1).times { tools_call(held, "sync_resource", id: @resource.id.to_s) }

    refused = Tenant.switch(@tenant) { AuditEvent.newest_first.first }

    assert_equal "sync_resource", refused.action
    assert_equal "denied", refused.status
    assert_match(/is the ceiling/, refused.detail)
  end

  private

    def origin_for(tenant)
      "http://#{tenant.subdomain}.things.test"
    end

    def host_for(tenant)
      { "HOST" => "#{tenant.subdomain}.things.test" }
    end

    def bearer(tenant, scopes)
      token = issuer.mint(
        subdomain: tenant.subdomain, scopes: scopes,
        audience: "#{origin_for(tenant)}/mcp"
      )

      { "Authorization" => "Bearer #{token}" }
    end

    def rpc(method, params = nil)
      { jsonrpc: "2.0", id: SecureRandom.uuid, method: method, params: params }.compact
    end

    def tools_call(held, name, **arguments)
      post "/mcp", headers: host_for(@tenant).merge(held),
                   params: rpc("tools/call", name: name, arguments: arguments), as: :json

      assert_response :success
      response.parsed_body
    end
end
