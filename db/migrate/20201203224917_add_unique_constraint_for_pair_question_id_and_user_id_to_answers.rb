# frozen_string_literal: true
#
class AddUniqueConstraintForPairQuestionIdAndUserIdToAnswers < ActiveRecord::Migration[6.0]
  def change
    add_index :answers, %i[question_id user_id], unique: true
  end
end
