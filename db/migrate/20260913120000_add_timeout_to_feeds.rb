class AddTimeoutToFeeds < ActiveRecord::Migration[8.1]
  def change
    add_column :feeds, :timeout, :integer
  end
end
