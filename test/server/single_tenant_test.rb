require "test_helper"

class SingleTenantTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = Tenant.create!(subdomain: "demo", name: "Demo items")
  end

  def with_pinned(subdomain, declared: [])
    was_tenant = Rails.configuration.uris.tenant
    was_tenants = Rails.configuration.uris.tenants

    Rails.configuration.uris.tenant = subdomain
    Rails.configuration.uris.tenants = declared

    yield
  ensure
    Rails.configuration.uris.tenant = was_tenant
    Rails.configuration.uris.tenants = was_tenants
  end

  test "a pinned tenant answers at a hostname that names no subdomain of its own" do
    with_pinned(@tenant.subdomain) do
      get "http://uris.test/up"

      assert_response :success
    end
  end

  test "a pinned tenant answers at another tenant's hostname" do
    other = Tenant.create!(subdomain: "acme", name: "Acme")

    with_pinned(@tenant.subdomain) do
      assert_equal @tenant, Tenant.resolve("#{other.subdomain}.uris.test")
    end
  end

  test "a pinned tenant answers at a label that could never be a subdomain" do
    with_pinned(@tenant.subdomain) do
      assert_equal @tenant, Tenant.resolve("-nope-.uris.test")
    end
  end

  test "an unpinned server still reads the tenant off the hostname" do
    other = Tenant.create!(subdomain: "acme", name: "Acme")

    assert_equal other, Tenant.resolve("acme.uris.test")
    assert_equal @tenant, Tenant.resolve("demo.uris.test")
  end

  test "declaring one tenant and a list of them at once is refused" do
    with_pinned(@tenant.subdomain, declared: %w[acme]) do
      assert_raises(Tenant::TenancyConflict) { Tenant.declared }
    end
  end

  test "declaring ensures every named tenant exists, and is idempotent" do
    with_pinned(nil, declared: %w[demo acme]) do
      assert_difference -> { Tenant.count }, 1 do
        assert_equal %w[acme demo], Tenant.declare!.map(&:subdomain).sort
      end

      assert_no_difference -> { Tenant.count } do
        Tenant.declare!
      end
    end
  end

  test "a pinned tenant declares only itself" do
    with_pinned("solo") do
      assert_equal [ "solo" ], Tenant.declared
    end
  end
end
