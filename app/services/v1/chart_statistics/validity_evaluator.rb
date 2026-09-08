# frozen_string_literal: true

# Decides whether a participant is valid for a chart that opted into the
# "N out of M answered variables" validity gate.
#
#   min == 0 (or key absent) -> gate off, everyone passes
#   answered >= min          -> passes on count; the rescue is not consulted
#   answered <  min          -> passes only if the rescue is enabled AND the
#                               0-filled score matched one of the chart's
#                               explicit (non-default) cases (rescued)
#
# "Answered" means the variable key is present in the participant's var values -
# nothing else. Skipped answers submit a blank `var` and are filtered out by
# `UserSession#all_var_values`; branched-around, never-reached, timed-out and
# draft answers leave no confirmed row at all. A genuine answer of 888 counts as
# answered (888 is only the CSV export's skip sentinel).
#
# The rescue is structural, not numeric: `positive_despite_missing_data: true` ties it to
# the chart's own cases, so a rescued participant can never land in the DEFAULT category.
# That is enforced on the LABEL, not merely on pattern-object identity - aggregation
# buckets purely by label string, so a case whose label duplicates `default_pattern`'s
# label does not rescue either.
#
# The guarantee is narrow and it is structural, not semantic: it says only "not the
# default category". It gives NO protection when the chart's explicit cases already cover
# the low/negative range. A multi-band chart (`>=15 Severe`, `>=10 Moderate`, `>=5 Mild`,
# `>=0 Minimal`) matches every score against an explicit case, so every below-minimum
# participant is rescued into a low band; a chart configured "backwards" (explicit case =
# the negative outcome, default = positive) rescues into the negative one. CIAS cannot
# know which case is clinically negative. For charts configured the recommended way (the
# explicit case = the positive screen) the rescue does exactly what was asked.
#
# `matched_pattern` must be the matched pattern Hash from `Chart#calculate`
# (or nil). The `is_a?(Hash)` check is load-bearing: `FormulaInterface#calculate`
# returns the truthy sentinel STRINGS 'ZeroDivisionError'/'OtherFormulaError' on
# evaluation errors, and an unfiltered caller must never be able to turn
# "formula errored" into "rescued". A boolean OR-formula chart whose result
# matches an explicit case (e.g. `=true`) IS rescuable - the pattern match
# replaced the old numeric-score check, so no arithmetic ever touches the score.
#
# The legacy `positive_despite_missing_threshold` key was replaced by the boolean before the
# feature ever deployed and is no longer schema-declared, so a formula carrying it now fails
# validation. It is never read here either - such a chart reads as rescue-off.
class V1::ChartStatistics::ValidityEvaluator
  Result = Struct.new(:variable_count, :answered_count, :passed, :rescued, keyword_init: true)

  def self.call(chart, all_var_values, score = nil, matched_pattern: nil)
    new(chart, all_var_values, score, matched_pattern: matched_pattern).call
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

  def self.rescue_enabled?(chart)
    chart.formula.to_h['positive_despite_missing_data'] == true
  end

  def initialize(chart, all_var_values, score = nil, matched_pattern: nil)
    @chart = chart
    @all_var_values = all_var_values || {}
    # Unused in the decision, and the caller logs its own score (create.rb:98-101, 117) -
    # retained per the phase-5 contract so the signature can carry it for diagnostics.
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
    # A rescue needs something to rescue. Without this, a participant branched around EVERY
    # variable scores 0, matches any band covering 0 - the normal clinical shape, PHQ-9 "0-4
    # Minimal" - and is published under that band's real label: `passed?` returns true, so
    # `Create#chartable?` short-circuits before its `answered_count.zero?` exclusion can run.
    # The guard belongs here rather than in `chartable?` because it is a property of the
    # rescue itself, and here it also keeps `passed?` honest for every other caller.
    return false if answered_count.zero?
    return false unless rescue_enabled?
    return false unless matched_pattern.is_a?(Hash)

    # The category a participant occupies is the LABEL STRING and nothing else - pie
    # aggregation groups by `label` (pie_chart.rb:29-33) and both bar generators read
    # only `patterns.first['label']` / `default_pattern['label']`. So a case whose label
    # duplicates the default's would rescue the participant INTO the default category as
    # rendered. Only a genuinely different category rescues.
    matched_pattern['label'] != default_pattern_label
  end

  # Nil-tolerant like every other reader here: `default_pattern` is neither required nor
  # constrained by formula.json, so it may be absent or not a Hash at all.
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
