class RenameThingIdsOnMergeProposals < ActiveRecord::Migration[8.1]
  def change
    rename_column :merge_proposals, :thing_ids, :item_ids
    rename_index :item_references, "index_thing_references_on_locator", "index_item_references_on_locator"
  end
end
