class AddAcceptedAnswersToQuestions < ActiveRecord::Migration[6.1]
  def change
    add_column :questions, :accepted_answers, :jsonb
  end
end
