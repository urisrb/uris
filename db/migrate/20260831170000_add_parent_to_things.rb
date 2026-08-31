class AddParentToThings < ActiveRecord::Migration[8.1]
  def change
    add_reference :things, :parent, foreign_key: { to_table: :things }, null: true
    add_index :things, [ :tenant_id, :parent_id ]
  end
end
