class AddSyncScheduleToResources < ActiveRecord::Migration[8.1]
  def change
    add_column :resources, :sync_interval, :integer
    add_column :resources, :next_sync_at, :datetime
    add_column :resources, :sync_started_at, :datetime
    add_column :resources, :synced_at, :datetime

    add_index :resources, [ :tenant_id, :next_sync_at ], where: "sync_interval IS NOT NULL",
              name: "index_resources_on_sync_due"
  end
end
