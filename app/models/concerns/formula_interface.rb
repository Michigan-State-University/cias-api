# frozen_string_literal: true

module FormulaInterface
  ZERO_DIVISION_ERROR = 'ZeroDivisionError'
  OTHER_FORMULA_ERROR = 'OtherFormulaError'

  def exploit_formula(var_values, payload, patterns)
    calculate(dentaku_service(var_values, payload, patterns))
  end

  def dentaku_service(var_values, payload, patterns, is_formula_interface = true)
    Calculations::DentakuService.new(var_values, payload, patterns, is_formula_interface)
  end

  def calculate(dentaku_service_object)
    dentaku_service_object.calculate
  rescue Dentaku::ZeroDivisionError
    ZERO_DIVISION_ERROR
  rescue StandardError
    OTHER_FORMULA_ERROR
  end
end
