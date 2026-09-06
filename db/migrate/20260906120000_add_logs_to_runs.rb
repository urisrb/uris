class AddLogsToRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :runs, :logs, :text
    add_column :runs, :lines, :integer, default: 0, null: false
  end
end
