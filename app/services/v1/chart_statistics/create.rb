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
    return unless valid_participant?

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
    result = calculated_formula

    result ? result['label'] : chart.formula['default_pattern']['label']
  end

  def dentaku_service
    @dentaku_service ||= chart.dentaku_service(
      all_var_values, formula['payload'], formula['patterns']
    )
  end

  def calculated_formula
    @calculated_formula ||= chart.calculate(dentaku_service)
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

  def validity
    @validity ||= validity_evaluator.call(chart, all_var_values, score)
  end

  def valid_participant?
    return true unless validity_gate_enabled?
    return true if validity.passed

    Rails.logger.info(
      "ChartStatistics::Create EXCLUDED chart_id=#{chart.id}: " \
      "user_session=#{user_session.id} did not meet the chart validity gate: " \
      "answered=#{validity.answered_count} required=#{validity_evaluator.min_answered_variables(chart)} " \
      "of=#{validity.variable_count.inspect} score=#{score.inspect} " \
      "threshold=#{validity_evaluator.threshold(chart).inspect}"
    )
    false
  end

  def upsert_chart_statistic
    chart_statistic = ChartStatistic.find_or_initialize_by(**chart_statistic_key)
    filled_at = user_session.finished_at || DateTime.current
    # Ordering guard, only ever triggered on the de-duplicated key: the back-fill iterates
    # finished sessions with no ORDER BY, so an older finish must not overwrite a newer one.
    # On the legacy key `filled_at` is derived from the `user_session` that is part of the
    # key, so a re-run always recomputes the same value and this returns false.
    return if chart_statistic.filled_at.present? && filled_at < chart_statistic.filled_at

    chart_statistic.label = label
    chart_statistic.user_session = user_session
    chart_statistic.filled_at = filled_at
    chart_statistic.save!
  end

  # `min == 0` keeps today's key: one row per (label, dimensions, user_session). With the
  # gate on, `label` and `user_session` drop out of the key and become plain assignments,
  # leaving exactly one row per participant per chart.
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
    return false if missing_vars.empty?

    required_var_names = missing_vars.map { |v| v.split('.').last }

    owning_question_ids = Question.joins(question_group: :session)
                                  .where(sessions: { intervention_id: user_session.session.intervention_id })
                                  .select { |q| q.question_variables.compact.intersect?(required_var_names) }
                                  .map(&:id)
    return false if owning_question_ids.empty?

    latest_user_session_ids = user_session.user_intervention.latest_user_sessions.map(&:id)

    answered_question_ids = Answer.confirmed
                                  .where(user_session_id: latest_user_session_ids,
                                         question_id: owning_question_ids)
                                  .pluck(:question_id).uniq

    (owning_question_ids - answered_question_ids).any?
  end
end
