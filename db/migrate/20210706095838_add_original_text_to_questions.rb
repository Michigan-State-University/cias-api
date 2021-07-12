class AddOriginalTextToQuestions < ActiveRecord::Migration[6.0]
  def change
    add_column :questions, :original_text, :jsonb
  end
end
