class AddNoteToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :note, :text
  end
end
