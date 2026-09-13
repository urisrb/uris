class AddConnectingToResources < ActiveRecord::Migration[8.1]
  def change
    add_column :resources, :connected_by, :string
    add_column :resources, :needs_connect_at, :datetime
  end
end
