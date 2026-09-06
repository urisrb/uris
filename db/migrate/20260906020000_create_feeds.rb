class CreateFeeds < ActiveRecord::Migration[8.1]
  include TenantIsolation

  def up
    create_table :feeds do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :name
      t.text :prompt, null: false
      t.string :role, null: false, default: "agent"
      t.integer :turns
      t.datetime :ran_at
      t.timestamps
    end

    add_index :feeds, [ :tenant_id, :slug ], unique: true

    enable_row_level_security :feeds

    add_reference :runs, :feed, foreign_key: true, index: true
  end

  def down
    remove_reference :runs, :feed
    drop_table :feeds
  end
end
