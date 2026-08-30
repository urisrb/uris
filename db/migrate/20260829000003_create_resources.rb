class CreateResources < ActiveRecord::Migration[8.1]
  include TenantIsolation

  def up
    create_table :resources do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :type, null: false
      t.string :key, null: false
      t.string :name
      t.jsonb :details, null: false, default: {}
      t.text :credentials
      t.datetime :archived_at
      t.timestamps
    end

    add_index :resources, [ :tenant_id, :type, :key ], unique: true

    enable_row_level_security :resources
  end

  def down
    drop_table :resources
  end
end
