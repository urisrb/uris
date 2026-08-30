class CreateResourceBlobs < ActiveRecord::Migration[8.1]
  include TenantIsolation

  def up
    create_table :resource_blobs do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :resource, null: false, foreign_key: true
      t.string :key, null: false
      t.string :content_type
      t.binary :bytes, null: false
      t.timestamps
    end

    add_index :resource_blobs, [ :tenant_id, :resource_id, :key ], unique: true

    enable_row_level_security :resource_blobs
  end

  def down
    drop_table :resource_blobs
  end
end
