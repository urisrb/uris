class AddViaToResources < ActiveRecord::Migration[8.1]
  def up
    add_column :resources, :via_id, :bigint

    add_index :resources, [ :tenant_id, :via_id ], where: "via_id IS NOT NULL",
              name: "index_resources_on_via"

    add_index :resources, [ :id, :tenant_id ], unique: true,
              name: "index_resources_on_id_and_tenant_id"

    execute <<~SQL
      ALTER TABLE resources
        ADD CONSTRAINT fk_resources_via
        FOREIGN KEY (via_id, tenant_id) REFERENCES resources (id, tenant_id)
        ON DELETE RESTRICT
    SQL
  end

  def down
    execute "ALTER TABLE resources DROP CONSTRAINT fk_resources_via"
    remove_index :resources, name: "index_resources_on_id_and_tenant_id"
    remove_index :resources, name: "index_resources_on_via"
    remove_column :resources, :via_id
  end
end
