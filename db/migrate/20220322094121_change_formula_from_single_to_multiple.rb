# frozen_string_literal: true

class ChangeFormulaFromSingleToMultiple < ActiveRecord::Migration[6.1]
  def change
    Rake::Task['one_time_use:change_single_formula_to_multiples'].invoke
  end
end
