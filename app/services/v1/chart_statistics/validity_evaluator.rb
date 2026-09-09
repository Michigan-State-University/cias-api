# frozen_string_literal: true

# Decides whether a participant is valid for a chart that opted into the "N out of M
# answered variables" validity gate. "Answered" means the variable key is present in the
# participant's var values: skipped answers submit a blank `var` and are dropped by
# `UserSession#all_var_values`, while branched-around, never-reached, timed-out and draft
# answers leave no confirmed row at all. A genuine answer of 888 counts as answered (888 is
# only the CSV export's skip sentinel).
class V1::ChartStatistics::ValidityEvaluator
  Result = Struct.new(:variable_count, :answered_count, :passed, :rescued, keyword_init: true)

  def self.call(chart, all_var_values, score = nil, matched_pattern: nil)
    new(chart, all_var_values, score, matched_pattern: matched_pattern).call
  end

  def self.enabled?(chart)
    min_answered_variables(chart).positive?
  end

  def self.min_answered_variables(chart)
    value = chart.formula.to_h['min_answered_variables']
    value.is_a?(Integer) ? value : 0
  end

  def self.rescue_enabled?(chart)
    chart.formula.to_h['positive_despite_missing_data'] == true
  end

  def initialize(chart, all_var_values, score = nil, matched_pattern: nil)
    @chart = chart
    @all_var_values = all_var_values || {}
    # Unused in the decision - retained so the signature can carry it for diagnostics.
    @score = score
    @matched_pattern = matched_pattern
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

  attr_reader :chart, :all_var_values, :score, :matched_pattern

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
    return false if answered_count.zero?
    return false unless rescue_enabled?
    return false unless matched_pattern.is_a?(Hash)

    matched_pattern['label'] != default_pattern_label
  end

  def default_pattern_label
    default_pattern = chart.formula.to_h['default_pattern']

    default_pattern.is_a?(Hash) ? default_pattern['label'] : nil
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

  def rescue_enabled?
    self.class.rescue_enabled?(chart)
  end
end
