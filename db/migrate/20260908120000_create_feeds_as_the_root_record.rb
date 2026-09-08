class CreateFeedsAsTheRootRecord < ActiveRecord::Migration[8.1]
  include TenantIsolation

  def up
    drop_table :feed_items
    drop_table :item_references
    drop_table :prompts
    drop_table :items

    remove_column :runs, :feed_id

    drop_table :feeds

    rename_column :merge_proposals, :item_ids, :feed_ids

    create_table :feeds do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :type, null: false
      t.string :key, null: false
      t.string :title
      t.text :note
      t.references :parent, foreign_key: { to_table: :feeds }
      t.string :origin, null: false, default: "resource"
      t.column :embedding, "double precision[]"
      t.string :embedded_digest
      t.datetime :embedded_at
      t.timestamps
    end

    add_index :feeds, [ :tenant_id, :type, :key ], unique: true,
              where: "type IN ('uris:tag', 'uris:feed')",
              name: "index_feeds_on_one_row_per_address"
    add_index :feeds, [ :tenant_id, :type ]
    add_index :feeds, [ :tenant_id, :key ]
    add_index :feeds, [ :tenant_id, :created_at ]
    add_index :feeds, [ :tenant_id, :origin ]
    add_index :feeds, [ :tenant_id, :parent_id ]
    add_index :feeds, [ :tenant_id, :id ], where: "embedded_at IS NULL",
              name: "index_feeds_awaiting_a_vector"

    enable_row_level_security :feeds

    create_table :feed_references do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :feed, null: false, foreign_key: true
      t.references :resource, null: false, foreign_key: true
      t.string :role, null: false, default: "original"
      t.jsonb :locator, null: false, default: {}
      t.string :locator_key
      t.string :mime
      t.bigint :size
      t.string :digest
      t.string :version
      t.string :source_version
      t.datetime :changed_at
      t.datetime :analyzed_at
      t.timestamps
    end

    add_index :feed_references, [ :tenant_id, :resource_id, :locator_key ],
              unique: true, where: "locator_key IS NOT NULL",
              name: "index_feed_references_on_locator"
    add_index :feed_references, [ :tenant_id, :feed_id, :role ]
    add_index :feed_references, [ :tenant_id, :analyzed_at ]

    enable_row_level_security :feed_references

    create_table :feed_edges do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :a, null: false, foreign_key: { to_table: :feeds }
      t.references :b, null: false, foreign_key: { to_table: :feeds }
      t.timestamps
    end

    add_index :feed_edges, [ :tenant_id, :a_id, :b_id ], unique: true
    add_index :feed_edges, [ :tenant_id, :b_id ]
    add_check_constraint :feed_edges, "a_id < b_id", name: "feed_edges_are_canonical"

    enable_row_level_security :feed_edges

    create_table :analyses do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :feed, null: false, foreign_key: true
      t.references :reference, foreign_key: { to_table: :feed_references }
      t.string :cause, null: false
      t.string :status, null: false, default: "queued"
      t.jsonb :steps, null: false, default: {}
      t.jsonb :turns, null: false, default: []
      t.text :logs
      t.integer :lines, null: false, default: 0
      t.string :error
      t.datetime :started_at
      t.datetime :finished_at
      t.datetime :deadline
      t.timestamps
    end

    add_index :analyses, [ :tenant_id, :feed_id, :id ]
    add_index :analyses, [ :tenant_id, :status ]
    add_index :analyses, [ :tenant_id, :finished_at ]

    enable_row_level_security :analyses

    create_table :schedules do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :feed, null: false, foreign_key: true
      t.text :prompt, null: false
      t.integer :turns
      t.integer :interval
      t.datetime :paused_at
      t.datetime :next_run_at
      t.datetime :ran_at
      t.timestamps
    end

    add_index :schedules, [ :tenant_id, :feed_id ], unique: true
    add_index :schedules, [ :tenant_id, :next_run_at ],
              where: "next_run_at IS NOT NULL AND paused_at IS NULL"

    enable_row_level_security :schedules
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
