class CreateGates < ActiveRecord::Migration[8.1]
  include TenantIsolation

  def up
    create_table :gates do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :key, null: false
      t.string :reference_type
      t.bigint :reference_id
      t.boolean :enabled, null: false, default: true
      t.boolean :live, null: false, default: true
      t.string :note
      t.timestamps
    end

    # NULLS NOT DISTINCT, or two key-wide gates for the same key both insert:
    # Postgres treats each NULL reference as its own value and the constraint
    # never fires on the rows that need it most.
    add_index :gates, [ :tenant_id, :key, :reference_type, :reference_id ],
              unique: true, nulls_not_distinct: true, name: "index_gates_on_scope"

    enable_row_level_security :gates
  end

  def down
    drop_table :gates
  end
end
