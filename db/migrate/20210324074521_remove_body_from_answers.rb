class RemoveBodyFromAnswers < ActiveRecord::Migration[6.0]
  def change
    remove_column :answers, :body, :jsonb
  end
end
