class CreateMergeProposals < ActiveRecord::Migration[8.1]
  include TenantIsolation

  def up
    create_table :merge_proposals do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :blocking_key, null: false
      t.string :reason, null: false
      t.jsonb :thing_ids, null: false, default: []
      t.string :status, null: false, default: "open"
      t.datetime :settled_at
      t.timestamps
    end

    add_index :merge_proposals, [ :tenant_id, :status, :id ]
    add_index :merge_proposals, [ :tenant_id, :blocking_key ], unique: true,
              where: "status = 'open'", name: "index_open_merge_proposals_on_key"

    enable_row_level_security :merge_proposals
  end

  def down
    drop_table :merge_proposals
  end
end
