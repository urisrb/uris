class AddResourceToThings < ActiveRecord::Migration[8.1]
  def change
    add_reference :things, :resource, foreign_key: true
    add_column :things, :locator_key, :string

    add_index :things, [ :tenant_id, :resource_id, :locator_key ],
              unique: true, where: "locator_key IS NOT NULL",
              name: "index_things_on_locator"
  end
end
