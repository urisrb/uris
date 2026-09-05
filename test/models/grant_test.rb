require "test_helper"

class GrantTest < ActiveSupport::TestCase
  setup do
    @tenant = Tenant.create!(subdomain: "grant-#{SecureRandom.hex(4)}", name: "Grants")
  end

  test "the granted scopes are the intersection with the ones this app defines" do
    grant = build(scope: "openid items:catalog:read profile items:resources:command nonsense")

    assert_equal [ "items:catalog:read", "items:resources:command" ], grant.scopes
  end

  test "the tool list is the grant, so an ungranted tool is never registered" do
    names = build(scope: "items:catalog:read").tools.map(&:tool_name)

    assert_equal %w[search_items get_item], names
    assert_empty build(scope: "openid").tools
  end

  test "a token whose tenant claim names another tenant is refused" do
    error = assert_raises(Grant::Denied) do
      build(scope: "items:catalog:read", tenant: { "subdomain" => "somebody-else" })
    end

    assert_match(/issued for somebody-else/, error.message)
  end

  test "a token with a matching tenant claim is accepted" do
    grant = build(scope: "items:catalog:read", tenant: { "subdomain" => @tenant.subdomain })

    assert grant.permits?("items:catalog:read")
  end

  test "a token carrying no tenant claim is accepted, since the audience already bound it" do
    assert build(scope: "items:catalog:read").permits?("items:catalog:read")
  end

  private

    def build(scope:, tenant: nil)
      claims = { "sub" => "someone", "scope" => scope, "exp" => 1.hour.from_now.to_i }
      claims["tenant"] = tenant if tenant

      Grant.new(tenant: @tenant, claims: Masks::Client::Claims.new(claims))
    end
end
