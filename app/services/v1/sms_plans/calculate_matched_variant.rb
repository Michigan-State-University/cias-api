# frozen_string_literal: true

class V1::SmsPlans::CalculateMatchedVariant
  def self.call(formula, variants, all_var_values)
    new(formula, variants, all_var_values).call
  end

  def initialize(formula, variants, all_var_values)
    @formula = formula
    @variants = variants
    @all_var_values = all_var_values
  end

  def call
    dentaku_calculator.store(**all_var_values) if all_var_values.present?
    dentaku_calculator.memory.transform_values! { |val| val.to_s.to_i }
    add_missing_variables(formula)
    result = dentaku_calculator.evaluate!(formula)

    variants.order(:created_at).detect do |variant|
      dentaku_calculator.evaluate("#{result}#{variant.formula_match}")
    end
  end

  private

  attr_reader :formula, :variants, :all_var_values

  def dentaku_calculator
    @dentaku_calculator ||= Dentaku::Calculator.new
  end

  def add_missing_variables(formula)
    missing_variables = dentaku_calculator.dependencies(formula)

    return if missing_variables.blank?

    dentaku_calculator.store(
      **missing_variables.index_with { |_var| 0 }
    )
  end
end
