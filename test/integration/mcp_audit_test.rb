require "test_helper"

class McpAuditTest < ActionDispatch::IntegrationTest
  include McpClient

  ALL = Grant::SCOPES

  setup do
    SearchIndex.reset!
    Rails.cache.clear

    @tenant = Tenant.create!(subdomain: "audit-#{SecureRandom.hex(4)}", name: "Audited")
    @other = Tenant.create!(subdomain: "audit-#{SecureRandom.hex(4)}", name: "Elsewhere")

    Tenant.switch(@tenant) do
      @resource = Resource::S3.create!(key: "audited-bucket", name: "Bucket",
                                       details: { "endpoint" => "http://127.0.0.1:1" })
      @thing = create_thing(kind: "pdf", title: "March invoice", locator_key: "invoices/march.pdf",
                            resource: @resource, locator: { "bucket" => "audited-bucket" })
    end

    SearchIndex.refresh!
  end

  def events(tenant = @tenant)
    Tenant.switch(tenant) { AuditEvent.newest_first.to_a }
  end

  test "every tool call is recorded against the token that made it" do
    tool(@tenant, ALL, "search_things", query: "invoice")

    event = events.first

    assert_equal "mcp", event.channel
    assert_equal "search_things", event.action
    assert_equal "ok", event.status
    assert_equal "things:catalog:read", event.scope
    assert_equal "test", event.subject
    assert_equal({ "query" => "invoice", "kind" => nil, "limit" => 50 }, event.arguments)
    assert event.duration_ms >= 0
    assert event.request_id.present?
  end

  test "a call the token does not carry the scope for is recorded as denied" do
    call(@tenant, [ "things:catalog:read" ], "tools/call",
         name: "search_things", arguments: { query: "invoice" })

    assert_equal "ok", events.first.status

    Tenant.switch(@tenant) { AuditEvent.delete_all }

    call(@tenant, [ "things:catalog:read" ], "tools/call",
         name: "sync_resource", arguments: { id: @resource.id.to_s })

    assert_empty events, "an ungranted tool is not registered, so no grant was exercised"
  end

  test "a tool that fails is recorded as an error, with what broke it" do
    reply = call(@tenant, ALL, "tools/call", name: "get_thing", arguments: { id: "999999" })

    assert reply.dig("result", "isError")

    event = events.first

    assert_equal "get_thing", event.action
    assert_equal "error", event.status
    assert_equal "no thing with id 999999", event.detail
  end

  test "an unauthenticated call is recorded as denied" do
    post "/mcp", headers: host_for(@tenant), params: rpc("tools/list"), as: :json

    assert_response :unauthorized

    event = events.first

    assert_equal "mcp", event.channel
    assert_equal "authorize", event.action
    assert_equal "denied", event.status
    assert_nil event.subject
  end

  test "a credential-shaped argument is redacted rather than stored" do
    Tenant.switch(@tenant) do
      AuditEvent.record(
        channel: "mcp", action: "command_resource", status: "ok",
        arguments: { "id" => "1", "arguments" => { "access_key_id" => "AKIA", "path" => "a/b" } }
      )
    end

    stored = events.first.arguments

    assert_equal "[redacted]", stored.dig("arguments", "access_key_id")
    assert_equal "a/b", stored.dig("arguments", "path")
  end

  test "a large argument is truncated rather than copied whole" do
    Tenant.switch(@tenant) do
      AuditEvent.record(channel: "mcp", action: "command_resource", status: "ok",
                        arguments: { "body" => "x" * 5_000, "parts" => Array.new(400, "y") })
    end

    stored = events.first.arguments

    assert_equal 200, stored["body"].length
    assert_equal "[400 items]", stored["parts"]
  end

  test "one tenant's audit log is invisible to another" do
    tool(@tenant, ALL, "search_things", query: "invoice")

    assert_equal 1, events.length
    assert_empty events(@other)

    Tenant.switch(@tenant) do
      assert_equal 1, AuditEvent.unscoped.count, "row-level security holds without the scope"
    end
  end

  test "the sweep drops what is past retention and keeps what is not" do
    Tenant.switch(@tenant) do
      AuditEvent.record(channel: "mcp", action: "search_things", status: "ok")
      AuditEvent.record(channel: "mcp", action: "search_things", status: "ok")
        .update!(created_at: 100.days.ago)
    end

    SweepAuditEventsJob.perform_now

    assert_equal 1, events.length
  end
end
