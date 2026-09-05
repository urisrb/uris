class CreatePrompts < ActiveRecord::Migration[8.1]
  include TenantIsolation

  def up
    create_table :prompts do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :resource, null: false, foreign_key: true
      t.references :promptable, polymorphic: true
      t.string :role, null: false
      t.string :model, null: false
      t.integer :attempt, null: false, default: 1
      t.text :request, null: false
      t.jsonb :response, null: false, default: {}
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :prompts, [ :tenant_id, :id ]
    add_index :prompts, [ :tenant_id, :promptable_type, :promptable_id ],
              name: "index_prompts_on_tenant_and_promptable"

    enable_row_level_security :prompts
  end

  def down
    drop_table :prompts
  end
end
