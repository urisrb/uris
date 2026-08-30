class AddAnalysisToThings < ActiveRecord::Migration[8.1]
  def change
    add_column :things, :analysis, :jsonb, null: false, default: {}
    add_column :things, :analyzed_at, :datetime

    add_index :things, [ :tenant_id, :analyzed_at ]
  end
end
