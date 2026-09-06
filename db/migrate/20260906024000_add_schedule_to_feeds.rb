class AddScheduleToFeeds < ActiveRecord::Migration[8.1]
  def change
    add_column :feeds, :interval, :integer
    add_column :feeds, :next_run_at, :datetime
    add_column :feeds, :paused_at, :datetime

    add_index :feeds, [ :tenant_id, :next_run_at ], where: "next_run_at IS NOT NULL AND paused_at IS NULL"
  end
end
