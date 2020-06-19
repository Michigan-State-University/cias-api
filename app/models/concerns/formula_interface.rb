# frozen_string_literal: true

module FormulaInterface
  def formula_patterns
    formula['patterns']
  end

  def formula_payload
    formula['payload']
  end

  def exploit_variables
    parser_runtime.evaluate!(formula_payload, collect_variables)
  end

  def exploit_patterns
    cache_exploit_variables = exploit_variables
    formula_patterns.each do |pattern|
      matched_pattern = parser_runtime.evaluate!("#{cache_exploit_variables} #{pattern['match']}")
      return pattern['target'] if matched_pattern
    end
  end

  private

  def parser_runtime
    @parser_runtime ||= Dentaku::Calculator.new
  end
end
