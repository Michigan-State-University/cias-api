class AddAlternativeBranchToAnswers < ActiveRecord::Migration[6.1]
  def change
    add_column :answers, :alternative_branch, :boolean, default: false
  end
end
