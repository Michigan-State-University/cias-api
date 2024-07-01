class AddFormulasFieldToQuestionGroups < ActiveRecord::Migration[6.1]
  def change
    add_column :question_groups, :formulas, :jsonb
  end
end
