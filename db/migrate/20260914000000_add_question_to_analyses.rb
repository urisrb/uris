class AddQuestionToAnalyses < ActiveRecord::Migration[8.1]
  def change
    add_column :analyses, :question, :text
  end
end
