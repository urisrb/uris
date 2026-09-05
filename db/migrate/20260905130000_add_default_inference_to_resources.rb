class AddDefaultInferenceToResources < ActiveRecord::Migration[8.1]
  def change
    add_column :resources, :default_inference, :boolean, null: false, default: false

    add_index :resources, :tenant_id, unique: true, where: "default_inference",
              name: "index_resources_on_one_default_inference_per_tenant"
  end
end
