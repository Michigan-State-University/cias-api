# frozen_string_literal: true

class ChangeQuestionAndSessionFormulaColumnName < ActiveRecord::Migration[6.1]
  def change
    rename_column :questions, :formula, :formulas
    rename_column :sessions, :formula, :formulas
  end
end
