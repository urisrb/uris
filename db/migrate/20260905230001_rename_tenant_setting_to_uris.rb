class RenameTenantSettingToUris < ActiveRecord::Migration[8.1]
  TABLES = %w[
    audit_events gates item_references items merge_proposals
    prompts resource_blobs resources runs settings
  ].freeze

  def up = swap("things", "uris")
  def down = swap("uris", "things")

  private

    def swap(from, to)
      TABLES.each do |table|
        execute "DROP POLICY tenant_isolation ON public.#{table};"
        execute <<~SQL
          CREATE POLICY tenant_isolation ON public.#{table}
            USING (tenant_id = NULLIF(current_setting('#{to}.tenant_id', true), '')::bigint)
            WITH CHECK (tenant_id = NULLIF(current_setting('#{to}.tenant_id', true), '')::bigint);
        SQL
      end
    end
end
