# frozen_string_literal: true

module FormulaInterface
  extend ActiveSupport::Concern

  def formula_processing
    parser_runtime.evaluate!(formula_payload)
  end

  private

  def parser_runtime
    @parser_runtime ||= Dentaku::Calculator.new
  end

  # harvest variables and values
  def formula_payload; end
end
