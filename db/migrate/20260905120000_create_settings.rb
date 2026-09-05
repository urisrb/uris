class CreateSettings < ActiveRecord::Migration[8.1]
  include TenantIsolation

  def up
    create_table :settings do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :subject
      t.string :key, null: false
      t.jsonb :value
      t.timestamps
    end

    # A personal setting is owned by a subject; a server-wide one has none.
    # NULLS NOT DISTINCT, or every server-wide row for a key inserts again:
    # Postgres counts each NULL subject as its own value and the constraint
    # never fires on exactly the rows that must stay unique.
    add_index :settings, [ :tenant_id, :subject, :key ],
              unique: true, nulls_not_distinct: true, name: "index_settings_on_scope"

    enable_row_level_security :settings
  end

  def down
    drop_table :settings
  end
end
