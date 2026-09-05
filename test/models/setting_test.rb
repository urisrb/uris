require "test_helper"

class SettingTest < ActiveSupport::TestCase
  setup do
    @jons = Tenant.create!(subdomain: "jons-#{SecureRandom.hex(4)}", name: "Jon's things")
    @acme = Tenant.create!(subdomain: "acme-#{SecureRandom.hex(4)}", name: "Acme")
  end

  test "a setting nobody has touched reads as its default" do
    Tenant.switch(@jons) do
      assert_equal "list", Setting.read("catalog_view", subject: "jon")
    end
  end

  test "what was written is what is read back" do
    Tenant.switch(@jons) do
      Setting.write!("catalog_view", "cards", subject: "jon")

      assert_equal "cards", Setting.read("catalog_view", subject: "jon")
    end
  end

  test "writing twice moves the same row rather than adding one" do
    Tenant.switch(@jons) do
      Setting.write!("catalog_view", "cards", subject: "jon")
      Setting.write!("catalog_view", "list", subject: "jon")

      assert_equal 1, Setting.where(key: "catalog_view", subject: "jon").count
      assert_equal "list", Setting.read("catalog_view", subject: "jon")
    end
  end

  test "a personal setting is one person's and not another's" do
    Tenant.switch(@jons) do
      Setting.write!("catalog_view", "cards", subject: "jon")

      assert_equal "cards", Setting.read("catalog_view", subject: "jon")
      assert_equal "list", Setting.read("catalog_view", subject: "someone-else")
    end
  end

  test "the same subject in another tenant reads their own setting" do
    Tenant.switch(@jons) { Setting.write!("catalog_view", "cards", subject: "jon") }

    Tenant.switch(@acme) do
      assert_equal "list", Setting.read("catalog_view", subject: "jon")
    end
  end

  test "row-level security holds when the application scope is gone" do
    Tenant.switch(@jons) { Setting.write!("catalog_view", "cards", subject: "jon") }

    Tenant.switch(@acme) do
      assert_empty Setting.unscoped.where(key: "catalog_view").pluck(:value)
    end
  end

  test "a value the definition does not allow is refused" do
    Tenant.switch(@jons) do
      assert_raises ActiveRecord::RecordInvalid do
        Setting.write!("catalog_view", "carousel", subject: "jon")
      end
    end
  end

  test "a key with no definition is refused" do
    Tenant.switch(@jons) do
      assert_raises Setting::Unknown do
        Setting.write!("nonsense", "cards", subject: "jon")
      end

      assert_raises Setting::Unknown do
        Setting.read("nonsense", subject: "jon")
      end
    end
  end

  test "a personal definition names the scopes that reach it" do
    definition = Setting.definition!("catalog_view")

    assert_predicate definition, :personal?
    assert_equal "settings:read", definition.reads
    assert_equal "settings:write", definition.writes
    assert_includes Grant::SCOPES, definition.reads
    assert_includes Grant::SCOPES, definition.writes
  end
end
