class CreateRuns < ActiveRecord::Migration[8.1]
  include TenantIsolation

  def up
    create_table :runs do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :resource, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "queued"
      t.jsonb :selector, null: false, default: {}
      t.integer :processed, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.datetime :deadline
      t.string :error
      t.timestamps
    end

    add_index :runs, [ :tenant_id, :status, :id ]
    add_index :runs, [ :tenant_id, :kind, :id ]

    enable_row_level_security :runs
  end

  def down
    drop_table :runs
  end
end
