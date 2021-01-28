class RemoveDefaultQuestionGroup < ActiveRecord::Migration[6.0]
  def up
    execute <<-SQL.squish
      update question_groups set "type" = 'QuestionGroup::Plain' where "type" = 'QuestionGroup::Default';
    SQL
  end

  def down
    execute <<-SQL.squish
      update question_groups set "type" = 'QuestionGroup::Default' where "position" = 0;
    SQL
  end
end
