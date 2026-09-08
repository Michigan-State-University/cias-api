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
  # variables keeps today's silent skip.
  #
  # That branch is LIVE-reachable, not replay-only, so do not delete it as dead code: a
  # participant who reached none of the chart's questions - at the finish of a session the
  # formula DOES reference (they were branched around every one of the chart's variables in
  # it), or, on the replay path, in any referenced session - would otherwise surface as a
  # visible Invalid slice before ever reaching the instrument. Until 2026-09-04 the branch
  # additionally absorbed a much larger population, because `CreateForUserSession` evaluated
  # every non-draft chart in the organization on every session finish with no session
  # filter; its session pre-filter now drops those charts before `Create` runs, so that is
  # no longer this branch's main job. The reachability above is what keeps it live.
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
  # With the gate OFF `insufficient_data?` is always false, so a live ungated chart can only
  # take the `persisted_insufficient_data?` branch when a researcher LOWERED `min` after
  # rows were written - an upgrade from the reserved label to a real one, which is the
  # intended direction. Otherwise both precedence branches fall through to the `filled_at`
  # comparison and the LATEST finish wins the row (label, user_session and filled_at all
  # move together). That is the intended ungated semantic, and it is pinned by spec rather
  # than assumed.
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

  # ONE row per (organization, health_system, health_clinic, chart, user) - for gated and
  # ungated charts alike. `label` and `user_session` are plain assignments
  # (`upsert_chart_statistic`), so a row still records its latest label and session; `label`
  # being OUT of the key is what lets a participant's row move between categories (and
  # between the reserved label and a real one) IN PLACE rather than accumulating one row
  # per outcome.
  #
  # The legacy ungated key carried `label` and `user_session`, while the score has always
  # been computed from the WHOLE `user_intervention` (`all_var_values` ->
  # `V1::UserInterventionService#var_values` -> `latest_user_sessions`). So once a chart's
  # formula was satisfied, a participant gained an ADDITIONAL row at every later session
  # finish, and aggregation counts rows, never people (pie_chart.rb:40, base.rb:59) - one
  # person, population 2. On a banded formula the two rows could even carry different
  # labels and put one participant in two slices of one pie. CIAS-4191 fixed this on the
  # gated path only, to keep `min == 0` byte-identical; that guarantee is deliberately
  # given up here (developer decision 2026-09-04) because the aligned feature's own
  # criterion - "the same population as the charts that already admit these participants" -
  # is unmeetable while one person can be counted twice.
  #
  # `health_clinic` stays in the key on purpose: a second row per clinic is documented
  # dimension behaviour (a multiple-fill retake can only land in a different clinic, since
  # `index_user_session_on_u_id_and_s_id_and_hc_id` is unconditionally unique), and clinic
  # filtering is how the dashboard reads those apart.
  #
  # ACCEPTED CONSEQUENCE: a key governs only NEW writes. Existing duplicate rows in
  # production are untouched, and a `chart_statistics` unique index cannot be added until
  # they are cleaned up - that cleanup needs its own decision (which row survives) and is a
  # data migration. Own ticket.
  #
  # Two consequences of that, both confined to legacy rows and to the REPLAY path:
  #   * `find_or_initialize_by` is `where(...).take` - no ORDER BY - so on a cell that
  #     already holds duplicates it updates an ARBITRARY one and leaves the siblings stale.
  #     The live path is unaffected in outcome (see below); aggregation counts rows either
  #     way, so this changes which garbage row is refreshed, not the count.
  #   * On the live path `filled_at` is the just-set `finished_at`, so `assignable?` is
  #     always true and the write always lands. Only a REPLAY (`REPLACE=false`, or a
  #     `draft -> data_collection` flip) can hand this an older finish, and then the write
  #     is declined with no log - correct (the row already carries a later finish), but it
  #     means a non-destructive replay cannot refresh a row whose `filled_at` is already
  #     ahead of every session the formula references. `REPLACE=true` is the refresh path.
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

  # Ungated (`min_answered_variables == 0`) charts drop a participant ONLY when they
  # answered none of the chart formula's variables. A participant branched around, timed
  # out of, or abandoning SOME of them is charted, those variables 0-fill, and they land in
  # an ordinary Matched / Not-matched category (client-confirmed 2026-09-03). That aligns
  # branched-around with skipped, which has always been charted this way: `Answer.confirmed`
  # is `where(draft: false)` only (answer.rb:17), so a skip leaves a confirmed row whose
  # body entry has a blank `var` while a branch-around leaves no row at all.
  #
  # TWO measurements, in this order, and NEITHER is redundant:
  #
  # 1. `chart.formula_variables - missing_vars` - the variables actually PRESENT in the
  #    participant's var values. One present variable is enough to chart them, and it costs
  #    no queries. `formula_variables` builds a FRESH calculator (chart.rb:59-63), which is
  #    why it returns the full set rather than the missing one; both calculators are
  #    `case_sensitive: true`, so the set difference is sound. `to_a` because
  #    `formula_variables` returns nil for a payload Dentaku cannot parse.
  #
  # 2. `UnansweredOwningQuestions.none_answered?` - measured on the OWNING QUESTION having
  #    a confirmed `Answer`, NEVER on var-values presence. This is the load-bearing half.
  #    The gated path measures answeredness as `all_var_values.key?` (validity_evaluator.rb
  #    :121-122); doing that here would newly DROP a participant who reached every chart
  #    question and SKIPPED every one - they have zero var-values present, and they are
  #    charted today (Carol and Eve of the worked example). The client explicitly required
  #    that population not change. Keying on the question instead makes the new drop set a
  #    strict subset of today's, so nobody charted today is lost.
  #
  # EVALUATION-ORDER SENSITIVITY - the call site must not move. `missing_vars` is only the
  # MISSING set because `exist_missing_variables?` has stored `all_var_values` into the
  # calculator and `add_missing_variables` has not yet run (dentaku_service.rb:21-24,34-37).
  # Touching `calculated_formula` earlier 0-fills calculator memory, makes `dependencies`
  # return `[]`, and silently turns this predicate into "everything is present".
  #
  # The guard this replaces also did a SECOND job, and that job survives here: `charts` used
  # to select every non-draft chart in the organization with no session filter, so this was
  # the only thing stopping a participant who finished session B from getting an all-zeros
  # row on every session-A chart in the org. Such a participant answered NONE of the chart's
  # variables, so they are still dropped. `CreateForUserSession`'s session pre-filter now
  # drops most of them earlier, but this remains the backstop for the replay path and for
  # `Create`'s direct callers.
  def answered_none_of_chart_variables?(missing_vars)
    return false if (chart.formula_variables.to_a - missing_vars).any?

    V1::ChartStatistics::UnansweredOwningQuestions.none_answered?(user_session, missing_vars)
  end
end
