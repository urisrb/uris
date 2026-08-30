class AddDefaultStorageToResources < ActiveRecord::Migration[8.1]
  def change
    add_column :resources, :default_storage, :boolean, null: false, default: false

    add_index :resources, :tenant_id, unique: true, where: "default_storage",
              name: "index_resources_on_one_default_storage_per_tenant"
  end
end
