class CreateThings < ActiveRecord::Migration[8.1]
  include TenantIsolation

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
end
