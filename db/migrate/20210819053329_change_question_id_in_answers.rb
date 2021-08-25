class ChangeQuestionIdInAnswers < ActiveRecord::Migration[6.0]
  def change
    change_column :answers, :question_id, :uuid, null: true
  end
end
