require "test_helper"

# The forcing function. Every scenario in this suite should eventually run with
# two tenants, because single-tenant assumptions do not announce themselves —
# they leak silently, months later, through a scope someone forgot.
class TenantIsolationTest < ActiveSupport::TestCase
  setup do
    @jons = Tenant.create!(subdomain: "jons-#{SecureRandom.hex(4)}", name: "Jon's things")
    @acme = Tenant.create!(subdomain: "acme-#{SecureRandom.hex(4)}", name: "Acme")

    Tenant.switch(@jons) { @jons_thing = Thing.create!(kind: "pdf", title: "Jon's invoice") }
    Tenant.switch(@acme) { @acme_thing = Thing.create!(kind: "pdf", title: "Acme's invoice") }
  end

  test "a tenant sees only its own things" do
    Tenant.switch(@jons) do
      assert_equal [ @jons_thing.id ], Thing.pluck(:id)
    end

    Tenant.switch(@acme) do
      assert_equal [ @acme_thing.id ], Thing.pluck(:id)
    end
  end

  test "row-level security holds when the application scope is gone" do
    # This is the assertion that proves the backstop is actually wired. Disable
    # the default scope — the thing a tired developer forgets — and the
    # database must still refuse. If this passes only because of `unscoped`
    # being scoped, FORCE ROW LEVEL SECURITY was never applied and the policy
    # is decoration.
    Tenant.switch(@jons) do
      assert_equal [ @jons_thing.id ], Thing.unscoped.pluck(:id)
    end
  end

  test "a thing cannot be written into another tenant" do
    # The WITH CHECK half of the policy. Asserted around the switch rather than
    # inside it, because the violation aborts to the savepoint on the way out.
    assert_raises ActiveRecord::StatementInvalid do
      Tenant.switch(@jons) do
        Thing.unscoped.create!(tenant_id: @acme.id, kind: "pdf", title: "smuggled")
      end
    end
  end

  test "no tenant in scope reads nothing at all" do
    # A forgotten scope should return an empty result, never another tenant's
    # rows. current_setting(..., true) returns NULL when unset, so the policy
    # matches nothing.
    assert_equal [], Thing.unscoped.pluck(:id)
  end

  test "a global id from another tenant does not resolve" do
    Tenant.switch(@jons) do
      context = { tenant: @jons, tenant_id: @jons.id }

      assert_nil ThingsSchema.object_from_id(@acme_thing.to_gid_param, context)
      assert_equal @jons_thing, ThingsSchema.object_from_id(@jons_thing.to_gid_param, context)
    end
  end
end
