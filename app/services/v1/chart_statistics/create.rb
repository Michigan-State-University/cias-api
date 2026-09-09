# frozen_string_literal: true

class V1::ChartStatistics::Create
  def self.call(chart, user_session, organization)
    new(chart, user_session, organization).call
  end

  def initialize(chart, user_session, organization)
    @chart = chart
    @user_session = user_session
    @organization = organization
  end

  def call
    return if health_clinic.nil?

    if dentaku_service.exist_missing_variables?
      missing_vars = dentaku_service.dentaku_calculator.dependencies(formula['payload'])
      invalid_vars = chart.validate_formula_variables(missing_vars, user_session.session.intervention)

      if invalid_vars.any?
        Rails.logger.error(
          "ChartStatistics::Create SKIPPED chart_id=#{chart.id}: " \
          "chart formula references variables that don't exist in any session question: " \
          "invalid_variables=#{invalid_vars.inspect}"
        )
        return
      end

      # An explicit `min_answered_variables` supersedes this guard: the chart owner has
      # declared how many answers are enough, and the remaining variables 0-fill.
      if !validity_gate_enabled? && answered_none_of_chart_variables?(missing_vars)
        Rails.logger.info(
          "ChartStatistics::Create SKIPPED chart_id=#{chart.id}: " \
          "user_session=#{user_session.id} answered NONE of the questions referenced by formula " \
          "(never reached this instrument). Formula: #{formula['payload']}"
        )
        return
      end

      Rails.logger.info("ChartStatistics::Create chart_id=#{chart.id}: missing variables from unselected options (will be set to 0): #{missing_vars.inspect}")
    end
    return if formula_error?
    return if zero_division_error?
    return unless inside_date_range?
    return unless chartable?

    upsert_chart_statistic
  rescue Dentaku::ParseError, Dentaku::TokenizerError, Dentaku::ArgumentError => e
    Rails.logger.error(
      "ChartStatistics::Create SKIPPED chart_id=#{chart.id}: " \
      "formula evaluation failed for chart '#{chart.name}': #{e.class} - #{e.message}. " \
      "Formula: #{formula['payload']}"
    )
    nil
  end

  private

  attr_reader :chart, :user_session, :organization

  def label
    return ChartStatistic::INSUFFICIENT_DATA_LABEL if insufficient_data?

    result = calculated_formula

    result ? result['label'] : chart.formula['default_pattern']['label']
  end

  def dentaku_service
    @dentaku_service ||= chart.dentaku_service(
      all_var_values, formula['payload'], formula['patterns']
    )
  end

  # `defined?` rather than `||=`: `chart.calculate` returns nil whenever no pattern matched, and
  # `||=` would then re-run the whole evaluation on every call site in the excluded path.
  def calculated_formula
    return @calculated_formula if defined?(@calculated_formula)

    @calculated_formula = chart.calculate(dentaku_service)
  end

  def formula
    chart.formula
  end

  def all_var_values
    @all_var_values ||= V1::UserInterventionService.new(
      user_session.user_intervention_id, nil
    ).var_values
  end

  def validity_gate_enabled?
    validity_evaluator.enabled?(chart)
  end

  def validity_evaluator
    V1::ChartStatistics::ValidityEvaluator
  end

  # The bare `calculated_formula` call is not dead code: `raw_result` is nil until evaluation runs.
  def score
    calculated_formula
    dentaku_service.raw_result
  end

  def validity
    @validity ||= validity_evaluator.call(chart, all_var_values, score, matched_pattern: calculated_formula)
  end

  # Deliberately positioned BEHIND the sentinel checks in `call`: invalid formula variables,
  # evaluation errors and out-of-date-range sessions all `return` earlier and keep their silent
  # skip - an evaluation-error participant must never surface as a visible Invalid slice.
  def chartable?
    return true unless validity_gate_enabled?
    return true if validity.passed

    if validity.answered_count.zero?
      log_gate_outcome('EXCLUDED', "answered none of the chart's variables, so it never reached the " \
                                   "instrument - no '#{ChartStatistic::INSUFFICIENT_DATA_LABEL}' row")
      return false
    end

    log_gate_outcome('INSUFFICIENT_DATA', 'did not meet the chart validity gate and is classified as ' \
                                          "'#{ChartStatistic::INSUFFICIENT_DATA_LABEL}'")
    true
  end

  def insufficient_data?
    validity_gate_enabled? && !validity.passed
  end

  def upsert_chart_statistic
    chart_statistic = ChartStatistic.find_or_initialize_by(**chart_statistic_key)
    filled_at = user_session.finished_at || DateTime.current
    return unless assignable?(chart_statistic, filled_at)

    chart_statistic.label = label
    chart_statistic.user_session = user_session
    chart_statistic.filled_at = filled_at
    chart_statistic.save!
  end

  # Outcome precedence FIRST, `filled_at` second. A real label beats a persisted Invalid row
  # regardless of `filled_at`, and an Invalid outcome never overwrites a real one. Replay has no
  # order - `CreateForUserSessions` iterates with no ORDER BY and `Charts::Regenerate` destroys and
  # replays - so a filled_at-only guard would make a row's final label depend on replay order.
  def assignable?(chart_statistic, filled_at)
    return true if chart_statistic.new_record?
    return true if persisted_insufficient_data?(chart_statistic) && !insufficient_data?

    if insufficient_data? && !persisted_insufficient_data?(chart_statistic)
      log_gate_outcome('RETAINED', 'fell below the chart validity gate but the participant is already charted ' \
                                   'under a real label - row kept, never downgraded')
      return false
    end

    chart_statistic.filled_at.blank? || filled_at >= chart_statistic.filled_at
  end

  def persisted_insufficient_data?(chart_statistic)
    chart_statistic.label == ChartStatistic::INSUFFICIENT_DATA_LABEL
  end

  def log_gate_outcome(outcome, detail)
    Rails.logger.info(
      "ChartStatistics::Create #{outcome} chart_id=#{chart.id}: " \
      "user_session=#{user_session.id} #{detail}: #{gate_diagnostics}"
    )
  end

  def gate_diagnostics
    "answered=#{validity.answered_count} required=#{validity_evaluator.min_answered_variables(chart)} " \
      "of=#{validity.variable_count.inspect} " \
      "rescue_enabled=#{validity_evaluator.rescue_enabled?(chart)} matched=#{calculated_formula.is_a?(Hash)}"
  end

  # ONE row per (organization, health_system, health_clinic, chart, user). `label` and
  # `user_session` are plain assignments, so a participant's row MOVES between categories in
  # place. With them IN the key (the legacy shape) a participant gained an extra row at every
  # later session finish, and aggregation counts rows, never people - one person, population 2.
  def chart_statistic_key
    { organization: organization, health_system: health_system, health_clinic: health_clinic,
      chart: chart, user: user_session.user }
  end

  def health_system
    health_clinic.health_system
  end

  def health_clinic
    user_session.health_clinic
  end

  def zero_division_error?
    calculated_formula == Chart::ZERO_DIVISION_ERROR
  end

  def formula_error?
    if calculated_formula == Chart::OTHER_FORMULA_ERROR
      Rails.logger.error(
        "ChartStatistics::Create SKIPPED chart_id=#{chart.id}: " \
        "formula evaluation failed for chart '#{chart.name}'. " \
        "Formula: #{formula['payload']}"
      )
      true
    else
      false
    end
  end

  def inside_date_range?
    return false if chart.date_range_start.present? && chart.date_range_start > user_session.finished_at
    # +1.day because FE sends and BE stores the BEGINNING of the last day, and we need to include this day as a whole as well
    return false if chart.date_range_end.present? && chart.date_range_end + 1.day <= user_session.finished_at

    true
  end

  # Drops a participant ONLY when they answered none of the formula's variables; some missing
  # variables 0-fill and they land in an ordinary Matched / Not-matched category. Answeredness is
  # measured on the OWNING QUESTION having a confirmed `Answer`, never on var-values presence -
  # the latter would newly drop a participant who reached every question and SKIPPED every one.
  #
  # EVALUATION-ORDER SENSITIVITY - the call site must not move. `missing_vars` is only the MISSING
  # set because `exist_missing_variables?` has stored the values and `add_missing_variables` has
  # not yet run. Touching `calculated_formula` earlier 0-fills calculator memory, makes
  # `dependencies` return `[]`, and silently turns this predicate into "everything is present".
  def answered_none_of_chart_variables?(missing_vars)
    return false if (chart.formula_variables.to_a - missing_vars).any?

    V1::ChartStatistics::UnansweredOwningQuestions.none_answered?(user_session, missing_vars)
  end
end
