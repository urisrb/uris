class AddEmbeddingsToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :embedding, :float, array: true
    add_column :items, :embedded_digest, :string
    add_column :items, :embedded_at, :datetime

    add_index :items, [ :tenant_id, :embedded_at ]
  end
end
