module TenantIsolation
  def enable_row_level_security(table)
    execute <<~SQL
      ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;
      ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;

      CREATE POLICY tenant_isolation ON #{table}
        USING (tenant_id = NULLIF(current_setting('things.tenant_id', true), '')::bigint)
        WITH CHECK (tenant_id = NULLIF(current_setting('things.tenant_id', true), '')::bigint);
    SQL
  end

  # A data migration runs as the table owner with no tenant set, so FORCE makes
  # every row invisible and a backfill quietly moves nothing. Lift it for the
  # duration rather than discovering the loss later.
  def without_row_level_security(*tables)
    tables.each { |table| execute "ALTER TABLE #{table} NO FORCE ROW LEVEL SECURITY" }
    yield
  ensure
    tables.each { |table| execute "ALTER TABLE #{table} FORCE ROW LEVEL SECURITY" }
  end
end
