require "test_helper"

class TenantIsolationTest < ActiveSupport::TestCase
  setup do
    @jons = Tenant.create!(subdomain: "jons-#{SecureRandom.hex(4)}", name: "Jon's things")
    @acme = Tenant.create!(subdomain: "acme-#{SecureRandom.hex(4)}", name: "Acme")

    Tenant.switch(@jons) { @jons_thing = Thing.create!(kind: "pdf", title: "Jon's invoice") }
    Tenant.switch(@acme) { @acme_thing = Thing.create!(kind: "pdf", title: "Acme's invoice") }
  end

  test "a tenant sees only its own things" do
    Tenant.switch(@jons) { assert_equal [ @jons_thing.id ], Thing.pluck(:id) }
    Tenant.switch(@acme) { assert_equal [ @acme_thing.id ], Thing.pluck(:id) }
  end

  test "row-level security holds when the application scope is gone" do
    Tenant.switch(@jons) do
      assert_equal [ @jons_thing.id ], Thing.unscoped.pluck(:id)
    end
  end

  test "a thing cannot be written into another tenant" do
    assert_raises ActiveRecord::StatementInvalid do
      Tenant.switch(@jons) do
        Thing.unscoped.create!(tenant_id: @acme.id, kind: "pdf", title: "smuggled")
      end
    end
  end

  test "no tenant in scope reads nothing at all" do
    assert_equal [], Thing.unscoped.pluck(:id)
  end

  test "a nested switch restores the outer tenant rather than clearing it" do
    Tenant.switch(@jons) do
      Tenant.switch(@acme) { assert_equal [ @acme_thing.id ], Thing.unscoped.pluck(:id) }

      assert_equal [ @jons_thing.id ], Thing.unscoped.pluck(:id)
    end
  end

  test "resources are isolated the same way" do
    Tenant.switch(@jons) { Resource::S3.create!(key: "jons-bucket", details: { "endpoint" => "http://x" }) }
    Tenant.switch(@acme) { Resource::S3.create!(key: "acme-bucket", details: { "endpoint" => "http://x" }) }

    Tenant.switch(@jons) { assert_equal [ "jons-bucket" ], Resource.unscoped.pluck(:key) }
    Tenant.switch(@acme) { assert_equal [ "acme-bucket" ], Resource.unscoped.pluck(:key) }
  end

  test "a global id from another tenant does not resolve" do
    Tenant.switch(@jons) do
      context = { tenant: @jons, tenant_id: @jons.id }

      assert_nil ThingsSchema.object_from_id(@acme_thing.to_gid_param, context)
      assert_equal @jons_thing, ThingsSchema.object_from_id(@jons_thing.to_gid_param, context)
    end
  end
end
