class DropMergeProposals < ActiveRecord::Migration[8.1]
  def up
    drop_table :merge_proposals
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
