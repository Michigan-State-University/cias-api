class AddUniqIndexToAnswers < ActiveRecord::Migration[6.1]
  def change
    add_index :answers, %i[user_session_id question_id], where: "(created_at > '#{DateTime.now.utc.to_s}'::timestamp)", unique: true
  end
end
