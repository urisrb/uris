class AddExpiresAtToFeeds < ActiveRecord::Migration[8.1]
  def change
    add_column :feeds, :expires_at, :datetime
    add_index :feeds, %i[tenant_id expires_at], where: "expires_at IS NOT NULL"
  end
end
