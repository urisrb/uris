class IsolateFeedItems < ActiveRecord::Migration[8.1]
  include TenantIsolation

  def up
    enable_row_level_security :feed_items
  end

  def down = nil
end
