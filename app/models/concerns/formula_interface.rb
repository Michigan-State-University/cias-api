# frozen_string_literal: true

module FormulaInterface
  ZERO_DIVISION_ERROR = 'ZeroDivisionError'
  OTHER_FORMULA_ERROR = 'OtherFormulaError'
  def formula_patterns
    formula['patterns']
  end

  def formula_payload
    formula['payload']
  end

  def exploit_formula(var_values, payload = formula_payload, _patterns = formula_patterns)
    Calculations::DentakuService.new(var_values, payload, _patterns, true).calculate
  rescue Dentaku::ZeroDivisionError
    ZERO_DIVISION_ERROR
  rescue StandardError
    OTHER_FORMULA_ERROR
  end
end
