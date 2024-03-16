class MigrateQuestionGroupsToNewSmsApproach < ActiveRecord::Migration[6.1]
  def up
    execute "
              UPDATE question_groups
              SET type = 'QuestionGroup::Classic::Finish'
              WHERE type = 'QuestionGroup::Finish';
            "
    execute "
              UPDATE question_groups
              SET type = 'QuestionGroup::Classic::Plain'
              WHERE type = 'QuestionGroup::Plain';
            "
  end

  def down
    execute "
              UPDATE question_groups
              SET type = 'QuestionGroup::Finish'
              WHERE type = 'QuestionGroup::Classic::Finish';
            "
    execute "
              UPDATE question_groups
              SET type = 'QuestionGroup::Plain'
              WHERE type = 'QuestionGroup::Classic::Plain';
            "
  end
end
