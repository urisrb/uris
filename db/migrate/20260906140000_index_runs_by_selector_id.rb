class IndexRunsBySelectorId < ActiveRecord::Migration[8.1]
  def change
    add_index :runs, "tenant_id, (selector->>'id')",
              name: "index_runs_on_tenant_and_selector_id"
  end
end
