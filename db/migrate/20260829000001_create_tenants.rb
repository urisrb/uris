class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :subdomain, null: false
      t.string :name, null: false
      t.timestamps
    end

    add_index :tenants, :subdomain, unique: true
  end
end
