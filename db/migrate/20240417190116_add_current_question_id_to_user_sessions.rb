class AddCurrentQuestionIdToUserSessions < ActiveRecord::Migration[6.1]
  def change
    add_reference :user_sessions, :current_question, references: :questions, index: true, type: :uuid
  end
end
