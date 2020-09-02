# frozen_string_literal: true

module FormulaInterface
  def formula_patterns
    formula['patterns']
  end

  def formula_payload
    formula['payload']
  end

  def exploit_formula(var_values, payload = formula_payload, patterns = formula_patterns)
    cache_exploit_variables = parser_runtime.evaluate!(payload, **var_values)
    patterns.each do |pattern|
      matched_pattern = parser_runtime.evaluate!("#{cache_exploit_variables} #{pattern['match']}")
      return pattern['target'] if matched_pattern
    end
  end

  private

  def parser_runtime
    @parser_runtime ||= Dentaku::Calculator.new
  end
end
