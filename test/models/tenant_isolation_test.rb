require "test_helper"

class TenantIsolationTest < ActiveSupport::TestCase
  setup do
    @demo = Tenant.create!(subdomain: "demo-#{SecureRandom.hex(4)}", name: "Demo items")
    @acme = Tenant.create!(subdomain: "acme-#{SecureRandom.hex(4)}", name: "Acme")

    Tenant.switch(@demo) { @demo_item = Feed.create!(type: Feed::FILE, key: "Demo invoice", title: "Demo invoice") }
    Tenant.switch(@acme) { @acme_item = Feed.create!(type: Feed::FILE, key: "Acme's invoice", title: "Acme's invoice") }
  end

  test "a tenant sees only its own items" do
    Tenant.switch(@demo) { assert_equal [ @demo_item.id ], Feed.pluck(:id) }
    Tenant.switch(@acme) { assert_equal [ @acme_item.id ], Feed.pluck(:id) }
  end

  test "row-level security holds when the application scope is gone" do
    Tenant.switch(@demo) do
      assert_equal [ @demo_item.id ], Feed.unscoped.pluck(:id)
    end
  end

  test "an item cannot be written into another tenant" do
    assert_raises ActiveRecord::StatementInvalid do
      Tenant.switch(@demo) do
        Feed.unscoped.create!(tenant_id: @acme.id, kind: "pdf", title: "smuggled")
      end
    end
  end

  test "no tenant in scope reads nothing at all" do
    assert_equal [], Feed.unscoped.pluck(:id)
  end

  test "a nested switch restores the outer tenant rather than clearing it" do
    Tenant.switch(@demo) do
      Tenant.switch(@acme) { assert_equal [ @acme_item.id ], Feed.unscoped.pluck(:id) }

      assert_equal [ @demo_item.id ], Feed.unscoped.pluck(:id)
    end
  end

  test "resources are isolated the same way" do
    Tenant.switch(@demo) { Resource::S3.create!(key: "demo-bucket", details: { "endpoint" => "http://x" }) }
    Tenant.switch(@acme) { Resource::S3.create!(key: "acme-bucket", details: { "endpoint" => "http://x" }) }

    Tenant.switch(@demo) { assert_equal [ "demo-bucket" ], Resource.unscoped.pluck(:key) }
    Tenant.switch(@acme) { assert_equal [ "acme-bucket" ], Resource.unscoped.pluck(:key) }
  end

  test "an id from another tenant does not resolve" do
    Tenant.switch(@demo) do
      assert_nil Feed.find_by(id: @acme_item.id)
      assert_equal @demo_item, Feed.find_by(id: @demo_item.id)
    end
  end
end
