# frozen_string_literal: true

class Calculations::DentakuService
  attr_reader :dentaku_calculator, :all_var_values, :formula, :formula_cases, :is_formula_interface

  def initialize(all_var_values, formula = nil, formula_cases = nil, is_formula_interface = false)
    @dentaku_calculator = Dentaku::Calculator.new(case_sensitive: true)
    @all_var_values = all_var_values
    @formula = formula
    @formula_cases = formula_cases
    @is_formula_interface = is_formula_interface
  end

  def calculate
    store_and_transform_values
    evaluate(formula, formula_cases, is_formula_interface)
  end

  def store_and_transform_values
    dentaku_calculator.store(**all_var_values) if all_var_values.present?
    dentaku_calculator.memory.transform_values! { |val| val.to_s.to_i }
  end

  def evaluate(formula, formula_cases, is_formula_interface = false)
    add_missing_variables(formula)
    result = dentaku_calculator.evaluate!(formula)

    is_formula_interface ? json_formula(result, formula_cases) : variant_formula(result, formula_cases)
  end

  def exist_missing_variables?
    store_and_transform_values
    dentaku_calculator.dependencies(formula).present?
  end

  private

  def add_missing_variables(formula)
    missing_variables = dentaku_calculator.dependencies(formula)
    return if missing_variables.blank?

    dentaku_calculator.store(
      **missing_variables.index_with { |_var| 0 }
    )
  end

  def variant_formula(result, formula_cases)
    formula_cases.order(:created_at).detect do |formula_case|
      dentaku_calculator.evaluate("#{result}#{formula_case.formula_match}")
    end
  end

  def json_formula(result, formula_cases)
    formula_cases.each do |formula_case|
      matched_formula = dentaku_calculator.evaluate!("#{result}#{formula_case['match']}")
      return formula_case if matched_formula
    end
    nil
  end
end
