class CreateThingReferences < ActiveRecord::Migration[8.1]
  include TenantIsolation

  def up
    create_table :thing_references do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :thing, null: false, foreign_key: true
      t.references :resource, null: false, foreign_key: true
      t.jsonb :locator, null: false, default: {}
      t.string :locator_key
      t.jsonb :analysis, null: false, default: {}
      t.datetime :analyzed_at
      t.timestamps
    end

    add_index :thing_references, [ :tenant_id, :resource_id, :locator_key ],
              unique: true, where: "locator_key IS NOT NULL",
              name: "index_thing_references_on_locator"
    add_index :thing_references, [ :tenant_id, :analyzed_at ]

    without_row_level_security(:things) do
      execute <<~SQL
        INSERT INTO thing_references
          (tenant_id, thing_id, resource_id, locator, locator_key,
           analysis, analyzed_at, created_at, updated_at)
        SELECT tenant_id, id, resource_id, locator, locator_key,
               analysis, analyzed_at, created_at, updated_at
        FROM things
        WHERE resource_id IS NOT NULL
      SQL
    end

    enable_row_level_security :thing_references

    remove_index :things, name: "index_things_on_locator"
    remove_index :things, column: [ :tenant_id, :analyzed_at ]
    remove_column :things, :resource_id
    remove_column :things, :locator
    remove_column :things, :locator_key
    remove_column :things, :analysis
    remove_column :things, :analyzed_at
  end

  def down
    add_reference :things, :resource, foreign_key: true
    add_column :things, :locator, :jsonb, null: false, default: {}
    add_column :things, :locator_key, :string
    add_column :things, :analysis, :jsonb, null: false, default: {}
    add_column :things, :analyzed_at, :datetime

    without_row_level_security(:things, :thing_references) do
      execute <<~SQL
        UPDATE things SET
          resource_id = r.resource_id,
          locator = r.locator,
          locator_key = r.locator_key,
          analysis = r.analysis,
          analyzed_at = r.analyzed_at
        FROM thing_references r
        WHERE r.thing_id = things.id
      SQL
    end

    add_index :things, [ :tenant_id, :resource_id, :locator_key ],
              unique: true, where: "locator_key IS NOT NULL",
              name: "index_things_on_locator"
    add_index :things, [ :tenant_id, :analyzed_at ]

    drop_table :thing_references
  end
end
