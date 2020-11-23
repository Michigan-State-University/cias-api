# frozen_string_literal: true

class ChangeQuestionGroup < ActiveRecord::Migration[6.0]
  def up
    add_column :question_groups, :type, :string
    add_index :question_groups, :type
    execute <<-SQL.squish
      update question_groups set "type" = 'QuestionGroup::Default' where "default" = true;
      update question_groups set "type" = 'QuestionGroup::Plain' where "default" = false;
    SQL
    remove_column :question_groups, :default
  end

  def down
    add_column :question_groups, :default, :boolean
    add_index :question_groups, :default
    execute <<-SQL.squish
      update question_groups set "default" = true where "type" = 'QuestionGroup::Default';
      update question_groups set "default" = false where "type" = 'QuestionGroup::Plain';
    SQL
    remove_index :question_groups, :type
    remove_column :question_groups, :type
  end
end
