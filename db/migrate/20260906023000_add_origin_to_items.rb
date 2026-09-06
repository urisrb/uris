class AddOriginToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :origin, :string, null: false, default: "resource"
    add_reference :items, :feed, foreign_key: true, index: false
    add_reference :items, :run, foreign_key: true, index: false

    add_index :items, [ :tenant_id, :origin ]
    add_index :items, [ :tenant_id, :feed_id ], where: "feed_id IS NOT NULL"

    create_table :feed_items do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :feed, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: true
      t.references :run, foreign_key: true
      t.timestamps
    end

    add_index :feed_items, [ :tenant_id, :feed_id, :item_id ], unique: true
  end
end
