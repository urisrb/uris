# A thing is a reference, not the bytes — the catalog is the product, and the
# bytes stay in the resource they came from. This table starts minimal on
# purpose; kind, locator, and analysis grow into it.
#
# It is also where row-level security gets proven. Application scopes are the
# primary enforcement; RLS is the backstop that turns a forgotten scope into an
# empty result instead of a leak.
class CreateThings < ActiveRecord::Migration[8.1]
  def up
    create_table :things do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :title
      t.jsonb :locator, null: false, default: {}
      t.timestamps
    end

    add_index :things, [ :tenant_id, :kind ]
    add_index :things, [ :tenant_id, :created_at ]

    enable_row_level_security :things
  end

  def down
    drop_table :things
  end

  private

    def enable_row_level_security(table)
      execute <<~SQL
        ALTER TABLE #{table} ENABLE ROW LEVEL SECURITY;

        -- Without FORCE, the table owner silently bypasses every policy — and
        -- Rails connects as the owner. This one line is the difference between
        -- a backstop and the appearance of one.
        ALTER TABLE #{table} FORCE ROW LEVEL SECURITY;

        -- The second argument to current_setting makes a missing setting
        -- return NULL rather than raise, and NULLIF covers the setting having
        -- been reset to an empty string. Either way a query issued with no
        -- tenant in scope matches nothing at all, rather than erroring on a
        -- failed cast.
        CREATE POLICY tenant_isolation ON #{table}
          USING (tenant_id = NULLIF(current_setting('things.tenant_id', true), '')::bigint)
          WITH CHECK (tenant_id = NULLIF(current_setting('things.tenant_id', true), '')::bigint);
      SQL
    end
end
