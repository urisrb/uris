class AddPairingToTenants < ActiveRecord::Migration[8.1]
  def change
    change_table :tenants, bulk: true do |t|
      t.string :client_id
      t.text :client_secret
      t.text :registration_access_token
      t.string :registration_client_uri
      t.datetime :paired_at
    end
  end
end
