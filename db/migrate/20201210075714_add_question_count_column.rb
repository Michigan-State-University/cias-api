# frozen_string_literal: true

class AddQuestionCountColumn < ActiveRecord::Migration[6.0]
  def change
    add_column :question_groups, :questions_count, :integer, default: 0
  end
end
