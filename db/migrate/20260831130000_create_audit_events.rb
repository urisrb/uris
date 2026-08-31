class CreateAuditEvents < ActiveRecord::Migration[8.1]
  include TenantIsolation

  def up
    create_table :audit_events do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :run, foreign_key: true
      t.string :channel, null: false
      t.string :action, null: false
      t.string :status, null: false
      t.string :scope
      t.string :subject
      t.string :client_id
      t.string :remote_ip
      t.string :request_id
      t.integer :duration_ms
      t.string :detail
      t.jsonb :arguments, null: false, default: {}
      t.datetime :created_at, null: false
    end

    add_index :audit_events, [ :tenant_id, :id ]
    add_index :audit_events, [ :tenant_id, :action, :id ]
    add_index :audit_events, [ :tenant_id, :status, :id ]

    enable_row_level_security :audit_events
  end

  def down
    drop_table :audit_events
  end
end
