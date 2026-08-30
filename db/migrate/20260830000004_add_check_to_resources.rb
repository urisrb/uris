class AddCheckToResources < ActiveRecord::Migration[8.1]
  def change
    add_column :resources, :checked_at, :datetime
    add_column :resources, :check_error, :string
  end
end
