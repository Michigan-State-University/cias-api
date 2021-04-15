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
    dentaku_service.calculate
  end

  private

  attr_reader :formula, :variants, :all_var_values

  def dentaku_service
    @dentaku_service ||= Calculations::DentakuService.new(all_var_values, formula, variants)
  end
end
