class IndexItemsAwaitingAVector < ActiveRecord::Migration[8.1]
  def change
    remove_index :items, [ :tenant_id, :embedded_at ]

    add_index :items, [ :tenant_id, :id ], where: "embedded_at IS NULL",
                                           name: "index_items_awaiting_a_vector"
  end
end
