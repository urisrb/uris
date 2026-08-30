class AddVersionsToThingReferences < ActiveRecord::Migration[8.1]
  def change
    change_table :thing_references, bulk: true do |t|
      t.string :version
      t.string :source_version
      t.datetime :changed_at
    end
  end
end
