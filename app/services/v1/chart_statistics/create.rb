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
      if !validity_gate_enabled? && any_owning_question_unanswered?(missing_vars)
        Rails.logger.info(
          "ChartStatistics::Create SKIPPED chart_id=#{chart.id}: " \
          "user_session=#{user_session.id} did not reach all questions referenced by formula " \
          "(branched-around or partial completion). Formula: #{formula['payload']}"
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

  # `defined?` rather than `||=`: `chart.calculate` returns nil for every participant whose
  # score matched no pattern, and `||=` would re-run the whole Dentaku evaluation on each of
  # the six call sites in the excluded path.
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

  # The 0-filled value the payload evaluated to, before pattern matching.
  # Touching `calculated_formula` (memoised) guarantees the evaluation has run.
  def score
    calculated_formula
    dentaku_service.raw_result
  end

  # `score` forces the memoised evaluation, so `calculated_formula` is the matched
  # pattern Hash or nil here (the error sentinels short-circuited in `call`).
  def validity
    @validity ||= validity_evaluator.call(chart, all_var_values, score, matched_pattern: calculated_formula)
  end

  # A below-minimum, non-rescued participant is no longer dropped at the gate: they are
  # persisted under the reserved label so they stay VISIBLE as their own pie category
  # (CIAS-4191 phase 6). One exception - a participant who answered NONE of the chart's
  # variables keeps today's silent skip: `CreateForUserSession` evaluates every non-draft
  # chart in the organization on every session finish, so a participant finishing session A
  # of an intervention whose gated chart covers session B would otherwise surface as a
  # visible Invalid slice before ever reaching the instrument.
  #
  # Deliberately positioned BEHIND the sentinel checks in `call`: invalid formula variables,
  # evaluation errors (`formula_error?` / `zero_division_error?`) and out-of-date-range
  # sessions all `return` earlier and keep today's silent skip. An evaluation-error
  # participant must never surface as Invalid, and the rescue needs the evaluation those
  # checks force - so this gate must not be moved ahead of them.
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

  # The outcome class of this (chart, participant) evaluation: true when the gate rejected
  # them, which is exactly when `label` becomes the reserved label. Both the label selector
  # and the precedence lattice key off it. `validity` is never constructed with the gate
  # off, which is what keeps `min == 0` byte-identical.
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

  # Outcome precedence FIRST, `filled_at` ordering second - and only ever consequential on
  # the de-duplicated key.
  #
  # A real-label outcome (passed or rescued) beats a persisted Invalid row REGARDLESS of
  # `filled_at`; an Invalid outcome never overwrites a real-label row (the 2026-08-04
  # "retain" decision - exclusion must not become retraction-by-relabel). The `filled_at`
  # ordering guard therefore applies only WITHIN one outcome class: real vs real, or
  # Invalid vs Invalid.
  #
  # Why ordering alone is not enough: `CreateForUserSessions` iterates finished sessions
  # with no ORDER BY (create_for_user_sessions.rb:26-32) and `V1::Charts::Regenerate`
  # destroys and replays, so a back-fill can hand this service a NEWER Invalid finish
  # before an OLDER passing one. A filled_at-only guard would freeze that row at Invalid
  # while the live finish order would have kept the real label - the same data producing a
  # different chart depending on replay order. With the lattice, replay order cannot change
  # any row's final label.
  #
  # On the legacy (`min == 0`) key the gate is off and `label` is part of the key, so both
  # precedence branches fall through and this reduces to exactly today's comparison
  # (`filled_at` is derived from the keyed `user_session`, so a re-run recomputes the same
  # value and the row is re-saved unchanged).
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

  # One structured line per gate DECISION, every one carrying the same diagnostics tail so a log
  # capture can be filtered by keyword and still read the counts:
  #
  #   INSUFFICIENT_DATA - the gate classified this participant as insufficient-data. A row under
  #                       the reserved label follows, UNLESS a `RETAINED` line for the same
  #                       evaluation reports that an existing real label was kept instead.
  #   EXCLUDED          - no row at all (the participant answered none of the chart's variables).
  #   RETAINED          - nothing was written: a below-minimum finish reached an already-charted
  #                       participant and the no-downgrade half of the precedence lattice held.
  #
  # So TWO lines can fire for one evaluation (`INSUFFICIENT_DATA` then `RETAINED`) - the
  # classification and the persistence decision are separate facts, and the second is only knowable
  # after the row is loaded. Anyone counting Invalid participants from logs must subtract
  # `RETAINED`, or better, count rows.
  #
  # These are `info` lines, i.e. dev/QA instrumentation: production runs at `config.log_level =
  # :warn`, so none of them is emitted there.
  def log_gate_outcome(outcome, detail)
    Rails.logger.info(
      "ChartStatistics::Create #{outcome} chart_id=#{chart.id}: " \
      "user_session=#{user_session.id} #{detail}: #{gate_diagnostics}"
    )
  end

  def gate_diagnostics
    "answered=#{validity.answered_count} required=#{validity_evaluator.min_answered_variables(chart)} " \
      "of=#{validity.variable_count.inspect} score=#{score.inspect} " \
      "rescue_enabled=#{validity_evaluator.rescue_enabled?(chart)} matched=#{calculated_formula.is_a?(Hash)}"
  end

  # `min == 0` keeps today's key: one row per (label, dimensions, user_session). With the
  # gate on, `label` and `user_session` drop out of the key and become plain assignments,
  # leaving exactly one row per participant per chart per clinic. `label` being OUT of the
  # key is what lets a participant's row move between the reserved label and a real one
  # in place, rather than accumulating one row per outcome.
  def chart_statistic_key
    key = { organization: organization, health_system: health_system, health_clinic: health_clinic,
            chart: chart, user: user_session.user }
    return key if validity_gate_enabled?

    key.merge(label: label, user_session: user_session)
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

  def any_owning_question_unanswered?(missing_vars)
    V1::ChartStatistics::UnansweredOwningQuestions.call(user_session, missing_vars)
  end
end
