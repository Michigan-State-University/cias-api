# frozen_string_literal: true

class ChangeQuestionGroup < ActiveRecord::Migration[6.0]
  def up
    add_column :question_groups, :type, :string
    add_index :question_groups, :type
    QuestionGroup.where(default: true).update_all(type: 'QuestionGroup::Default')
    QuestionGroup.where(default: false).update_all(type: 'QuestionGroup::Plain')
    remove_column :question_groups, :default
  end

  def down
    add_column :question_groups, :default, :boolean
    add_index :question_groups, :default
    QuestionGroup.where(type: 'QuestionGroup::Default').update_all(default: true)
    QuestionGroup.where(default: false).update_all(type: 'QuestionGroup::Plain')
    remove_index :question_groups, :type
    remove_column :question_groups, :type
  end
end
