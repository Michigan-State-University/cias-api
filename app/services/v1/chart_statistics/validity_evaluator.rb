# frozen_string_literal: true

# Decides whether a participant is valid for a chart that opted into the
# "N out of M answered variables" validity gate.
#
#   min == 0 (or key absent) -> gate off, everyone passes
#   answered >= min          -> passes on count; the threshold is not consulted
#   answered <  min          -> passes only if a NUMERIC score clears the threshold (rescued)
#
# "Answered" means the variable key is present in the participant's var values -
# nothing else. Skipped answers submit a blank `var` and are filtered out by
# `UserSession#all_var_values`; branched-around, never-reached, timed-out and
# draft answers leave no confirmed row at all. A genuine answer of 888 counts as
# answered (888 is only the CSV export's skip sentinel).
#
# The Numeric check on `score` is load-bearing: an OR-style payload evaluates to
# true/false and `true >= 15` would raise NoMethodError, and the formula error
# sentinels ('ZeroDivisionError'/'OtherFormulaError') are strings. Non-numeric
# scores simply never rescue.
class V1::ChartStatistics::ValidityEvaluator
  Result = Struct.new(:variable_count, :answered_count, :passed, :rescued, keyword_init: true)

  def self.call(chart, all_var_values, score = nil)
    new(chart, all_var_values, score).call
  end

  # Cheap reads callers need before any evaluation happens.
  # Legacy charts carry neither key, so both must tolerate nil.
  def self.enabled?(chart)
    min_answered_variables(chart).positive?
  end

  def self.min_answered_variables(chart)
    value = chart.formula.to_h['min_answered_variables']
    value.is_a?(Integer) ? value : 0
  end

  def self.threshold(chart)
    value = chart.formula.to_h['positive_despite_missing_threshold']
    value.is_a?(Numeric) ? value : nil
  end

  def initialize(chart, all_var_values, score = nil)
    @chart = chart
    @all_var_values = all_var_values || {}
    @score = score
  end

  def call
    Result.new(
      variable_count: chart.formula_variable_count,
      answered_count: answered_count,
      passed: passed?,
      rescued: rescued?
    )
  end

  private

  attr_reader :chart, :all_var_values, :score

  def enabled?
    min_answered_variables.positive?
  end

  def passed?
    return true unless enabled?
    return true if answered_count >= min_answered_variables

    rescued?
  end

  def rescued?
    return false unless enabled?
    return false if answered_count >= min_answered_variables
    return false if threshold.nil?
    return false unless score.is_a?(Numeric)

    score >= threshold
  end

  def answered_count
    @answered_count ||= formula_variables.count { |variable| all_var_values.key?(variable) }
  end

  def formula_variables
    @formula_variables ||= chart.formula_variables || []
  end

  def min_answered_variables
    @min_answered_variables ||= self.class.min_answered_variables(chart)
  end

  def threshold
    self.class.threshold(chart)
  end
end
