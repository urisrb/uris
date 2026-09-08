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
        Feed.unscoped.create!(tenant_id: @acme.id, type: Feed::FILE, key: "smuggled", title: "smuggled")
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

  test "a reference is isolated, since the policy is per table and not inherited" do
    mine = Tenant.switch(@demo) { referenced(@demo_item, "demo.pdf") }
    theirs = Tenant.switch(@acme) { referenced(@acme_item, "acme.pdf") }

    Tenant.switch(@demo) { assert_equal [ mine.id ], Reference.unscoped.pluck(:id) }
    Tenant.switch(@acme) { assert_equal [ theirs.id ], Reference.unscoped.pluck(:id) }
  end

  test "an analysis is isolated" do
    mine = Tenant.switch(@demo) { Analysis.open!(feed: @demo_item, cause: "manual") }
    theirs = Tenant.switch(@acme) { Analysis.open!(feed: @acme_item, cause: "manual") }

    Tenant.switch(@demo) { assert_equal [ mine.id ], Analysis.unscoped.pluck(:id) }
    Tenant.switch(@acme) { assert_equal [ theirs.id ], Analysis.unscoped.pluck(:id) }
  end

  test "an edge is isolated" do
    mine = Tenant.switch(@demo) { connected(@demo_item, "demo tag") }
    theirs = Tenant.switch(@acme) { connected(@acme_item, "acme tag") }

    Tenant.switch(@demo) { assert_equal [ mine.id ], Edge.unscoped.pluck(:id) }
    Tenant.switch(@acme) { assert_equal [ theirs.id ], Edge.unscoped.pluck(:id) }
  end

  test "a schedule is isolated" do
    mine = Tenant.switch(@demo) { scheduled("/demo") }
    theirs = Tenant.switch(@acme) { scheduled("/acme") }

    Tenant.switch(@demo) { assert_equal [ mine.id ], Schedule.unscoped.pluck(:id) }
    Tenant.switch(@acme) { assert_equal [ theirs.id ], Schedule.unscoped.pluck(:id) }
  end

  test "a reference cannot be written into another tenant either" do
    assert_raises ActiveRecord::StatementInvalid do
      Tenant.switch(@demo) do
        Reference.unscoped.create!(tenant_id: @acme.id, feed_id: @demo_item.id,
                                   resource_id: storage(@demo).id, locator_key: "smuggled.pdf",
                                   locator: {})
      end
    end
  end

  private

    def storage(tenant)
      @storages ||= {}
      @storages[tenant.id] ||= Tenant.switch(tenant) do
        Resource::Database.create!(key: "store-#{SecureRandom.hex(4)}")
      end
    end

    def referenced(feed, key)
      Reference.create!(feed: feed, resource: storage(Current.tenant),
                        locator_key: key, locator: {}, mime: MimeType.for_filename(key))
    end

    def connected(feed, key)
      feed.connect!(Feed.tag!(key))
    end

    def scheduled(key)
      Feed.create!(type: Feed::ADDRESS, key: key).create_schedule!(prompt: "anything new?")
    end
end
