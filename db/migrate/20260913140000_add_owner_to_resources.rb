class AddOwnerToResources < ActiveRecord::Migration[8.1]
  def change
    add_column :resources, :owner_subject, :string
    add_index :resources, %i[tenant_id owner_subject]
  end
end
