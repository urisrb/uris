require "test_helper"

module PretendsToBypass
  mattr_accessor :pretending, default: false

  def role_privileges
    return { "rolname" => "postgres", "bypasses" => true } if PretendsToBypass.pretending

    super
  end
end

Tenant.singleton_class.prepend(PretendsToBypass)

class RowLevelSecurityTest < ActiveSupport::TestCase
  setup do
    Rails.application.eager_load!

    @tables = ActiveRecord::Base.descendants
      .select { |model| model.include?(TenantScoped) }
      .map(&:table_name)
      .uniq
  end

  test "there is at least one tenant-scoped table to protect" do
    assert_not_empty @tables
  end

  test "every tenant-scoped table carries an isolation policy" do
    assert_empty @tables - policed,
                 "these tables have no tenant_isolation policy in this database, so the only " \
                 "thing separating tenants is the default scope in Ruby"
  end

  test "every table carrying a tenant_id carries an isolation policy too" do
    assert_empty carrying - policed,
                 "a migration gave these tables a tenant_id and never called " \
                 "enable_row_level_security, so the database will hand one tenant another's rows"
  end

  test "every table carrying a tenant_id has a model that scopes itself to one" do
    unscoped = carrying.reject do |table|
      models = ActiveRecord::Base.descendants.select { |model| model.table_name == table }

      models.any? && models.all? { |model| model.include?(TenantScoped) }
    end

    assert_empty unscoped,
                 "these tables are tenant data the application reads without TenantScoped, so " \
                 "every query against them depends on row-level security alone"
  end

  test "every tenant-scoped table forces row-level security on its owner" do
    forced = connection.select_values(<<~SQL)
      SELECT relname FROM pg_class WHERE relrowsecurity AND relforcerowsecurity
    SQL

    assert_empty @tables - forced,
                 "row-level security that is not FORCEd does not apply to the table owner, " \
                 "which is the role the application connects as"
  end

  test "the application does not connect as a role that bypasses row-level security" do
    bypasses = connection.select_value(<<~SQL)
      SELECT rolbypassrls OR rolsuper FROM pg_roles WHERE rolname = current_user
    SQL

    assert_not bypasses,
               "the application role can see through row-level security, which makes every " \
               "policy above decorative"
  end

  test "a role that bypasses row-level security is refused before a switch, not after" do
    forget_isolation
    PretendsToBypass.pretending = true

    tenant = Tenant.create!(subdomain: "exposed-#{SecureRandom.hex(4)}", name: "Exposed")

    refused = assert_raises(Tenant::Exposed) do
      Tenant.switch(tenant) { flunk "the switch went through on a role that sees every tenant" }
    end

    assert_match "postgres", refused.message
  ensure
    PretendsToBypass.pretending = false
    forget_isolation
  end

  private

    def forget_isolation
      Tenant.remove_instance_variable(:@isolated) if Tenant.instance_variable_defined?(:@isolated)
    end

    def policed
      @policed ||= connection.select_values(<<~SQL)
        SELECT tablename FROM pg_policies WHERE policyname = 'tenant_isolation'
      SQL
    end

    def carrying
      @carrying ||= connection.select_values(<<~SQL)
        SELECT table_name FROM information_schema.columns
        WHERE table_schema = 'public' AND column_name = 'tenant_id'
      SQL
    end

    def connection
      ActiveRecord::Base.connection
    end
end
