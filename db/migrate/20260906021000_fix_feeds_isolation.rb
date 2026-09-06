class FixFeedsIsolation < ActiveRecord::Migration[8.1]
  def up
    execute "DROP POLICY IF EXISTS tenant_isolation ON public.feeds;"
    execute <<~SQL
      CREATE POLICY tenant_isolation ON public.feeds
        USING (tenant_id = NULLIF(current_setting('uris.tenant_id', true), '')::bigint)
        WITH CHECK (tenant_id = NULLIF(current_setting('uris.tenant_id', true), '')::bigint);
    SQL
  end

  def down = nil
end
