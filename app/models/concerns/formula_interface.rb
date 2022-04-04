# frozen_string_literal: true

module FormulaInterface
  ZERO_DIVISION_ERROR = 'ZeroDivisionError'
  OTHER_FORMULA_ERROR = 'OtherFormulaError'

  def exploit_formula(var_values, payload, patterns)
    Calculations::DentakuService.new(var_values, payload, patterns, true).calculate
  rescue Dentaku::ZeroDivisionError
    ZERO_DIVISION_ERROR
  rescue StandardError
    OTHER_FORMULA_ERROR
  end
end
