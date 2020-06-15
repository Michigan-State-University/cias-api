# frozen_string_literal: true

module FormulaInterface
  extend ActiveSupport::Concern

  def formula_exploit
    parser_runtime.evaluate!(formula['payload'], collected_variables)
  end

  private

  def parser_runtime
    @parser_runtime ||= Dentaku::Calculator.new
  end

  def collected_variables
    Variables.new(self).collect
  end
end
