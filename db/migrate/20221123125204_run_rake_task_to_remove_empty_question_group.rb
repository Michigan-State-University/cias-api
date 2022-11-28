class RunRakeTaskToRemoveEmptyQuestionGroup < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['one_time_use:delete_empty_question_groups'].invoke
  end
end
