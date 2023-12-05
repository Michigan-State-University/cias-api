class AddUniqIndexToAnswers < ActiveRecord::Migration[6.1]
  def change
    add_index :answers, %i[user_session_id question_id], where: "(created_at > '2023-10-25 05:30:04'::timestamp)", unique: true
  end
end
