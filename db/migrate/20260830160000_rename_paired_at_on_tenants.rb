class RenamePairedAtOnTenants < ActiveRecord::Migration[8.1]
  def change
    rename_column :tenants, :paired_at, :connected_at
  end
end
