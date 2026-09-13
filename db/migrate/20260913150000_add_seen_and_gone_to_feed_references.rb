class AddSeenAndGoneToFeedReferences < ActiveRecord::Migration[8.1]
  def change
    add_column :feed_references, :seen_at, :datetime
    add_column :feed_references, :gone_at, :datetime
    add_index :feed_references, %i[tenant_id resource_id seen_at]
  end
end
