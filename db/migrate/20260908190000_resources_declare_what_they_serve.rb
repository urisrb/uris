class ResourcesDeclareWhatTheyServe < ActiveRecord::Migration[8.1]
  def up
    add_column :resources, :serving, :jsonb, null: false, default: {}
    add_index :resources, :serving, using: :gin

    Resource.reset_column_information
    Resource.restate!
  end

  def down
    remove_column :resources, :serving
  end
end
