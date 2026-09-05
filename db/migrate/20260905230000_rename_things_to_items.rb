class RenameThingsToItems < ActiveRecord::Migration[8.1]
  def change
    rename_table :things, :items
    rename_table :thing_references, :item_references
    rename_column :item_references, :thing_id, :item_id
  end
end
