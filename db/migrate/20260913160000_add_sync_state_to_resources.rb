class AddSyncStateToResources < ActiveRecord::Migration[8.1]
  def change
    add_column :resources, :sync_state, :jsonb, null: false, default: {}
    add_column :resources, :walked_at, :datetime
  end
end
