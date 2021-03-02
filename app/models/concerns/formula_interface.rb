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

  def exploit_formula(var_values, payload = formula_payload, patterns = formula_patterns)
    complete_var_values = supplement_missing_values(var_values, payload)
    calculated_formula = parser_runtime.evaluate!(payload, **complete_var_values)
    patterns.each do |pattern|
      matched_pattern = parser_runtime.evaluate!("#{calculated_formula} #{pattern['match']}")
      return pattern if matched_pattern
    end
    nil
  rescue Dentaku::ZeroDivisionError
    ZERO_DIVISION_ERROR
  rescue StandardError
    OTHER_FORMULA_ERROR
  end

  def supplement_missing_values(var_values, payload)
    parser_runtime.store(**var_values)
    missing_dependencies = parser_runtime.dependencies(payload)
    missing_dependencies.each do |dependency|
      var_values[dependency] = '0'
    end
    var_values
  end

  private

  def parser_runtime
    @parser_runtime ||= Dentaku::Calculator.new
  end
end
