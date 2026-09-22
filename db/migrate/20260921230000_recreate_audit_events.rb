class RecreateAuditEvents < ActiveRecord::Migration[8.1]
  include TenantIsolation

  def up
    drop_table :audit_events

    create_table :audit_events do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :actor, null: false
      t.string :actor_name
      t.string :via
      t.references :analysis, foreign_key: { on_delete: :nullify }
      t.references :feed, foreign_key: { on_delete: :nullify }
      t.string :told
      t.string :channel, null: false
      t.string :action, null: false
      t.string :status, null: false
      t.string :scope
      t.string :remote_ip
      t.string :request_id
      t.integer :duration_ms
      t.string :detail
      t.jsonb :arguments, null: false, default: {}
      t.datetime :created_at, null: false

      t.index [ :tenant_id, :id ]
      t.index [ :tenant_id, :status, :id ]
      t.index [ :tenant_id, :actor, :id ]
    end

    enable_row_level_security(:audit_events)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
