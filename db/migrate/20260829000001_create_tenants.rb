# Migration #1 is the tenant table, deliberately. Tenancy is the one property
# in this system that cannot be retrofitted cheaply, and every table after this
# one carries a tenant_id.
class CreateTenants < ActiveRecord::Migration[8.1]
  def change
    create_table :tenants do |t|
      t.string :subdomain, null: false
      t.string :name, null: false
      t.timestamps
    end

    # Tenants are addressed by subdomain, so this uniqueness is what makes
    # issuers, cookie isolation, and the aud claim fall out correctly.
    add_index :tenants, :subdomain, unique: true
  end
end
