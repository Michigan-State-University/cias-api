# frozen_string_literal: true

class V1::ChartStatistics::CreateForUserSession
  def self.call(user_session)
    new(user_session).call
  end

  def initialize(user_session)
    @user_session = user_session
  end

  def call
    # service should be run for action when the user session is finished
    return unless intervention.published?
    return unless organization

    charts.each do |chart|
      next if chart.status == 'draft'

      begin
        V1::ChartStatistics::Create.call(chart, user_session, organization)
      rescue StandardError => e
        Rails.logger.error(
          "ChartStatistics::CreateForUserSession FAILED for chart_id=#{chart.id}, " \
          "user_session_id=#{user_session.id}: #{e.class} - #{e.message}"
        )
      end
    end
  end

  private

  attr_reader :user_session

  def organization
    @organization ||= intervention.organization
  end

  def intervention
    @intervention ||= user_session.session.intervention
  end

  # Only the charts whose formula actually references the session that just finished.
  # Mirrors the replay path, which has always filtered this way
  # (`CreateForUserSessions#chart_session_variables`, create_for_user_sessions.rb:42-44) -
  # so a regenerate and a live finish now select the same population for the same chart.
  #
  # Without this, every non-draft chart in the ORGANIZATION was evaluated at every finish.
  # The retired never-reached guard used to absorb that (a participant who finished
  # session B answered none of a session-A chart's questions, so no row was written), and
  # the zero-answered rule still does - but two things it does NOT absorb:
  #
  #   * `filled_at` migration. With one row per participant, an `ht1`-scoped chart
  #     evaluated at an unrelated `ht3` finish finds the existing row and drags `filled_at`
  #     forward, relocating the participant from the month they were screened in to the
  #     month they happened to finish something else. On a monthly bar chart their bar
  #     moves. Skipping the chart keeps the date put.
  #   * The cross-intervention all-zeros leak - NARROWED, not closed. Two interventions in
  #     one organization sharing a bare question-variable name let a participant of
  #     intervention B write an all-zeros row on intervention A's chart:
  #     `Chart#validate_formula_variables` matches bare names intervention-wide and
  #     `UnansweredOwningQuestions` then bails out on `owning_question_ids.empty?`. The
  #     pre-filter drops the chart before any of that runs ONLY when the two interventions'
  #     session variables differ - which is the SESSION-clone case, since cloning a session
  #     renames its variable (`clone_jobs/session.rb:15`). A whole-INTERVENTION clone keeps
  #     every session variable verbatim (`Clone::Intervention#create_sessions` passes no
  #     `params:` and `Clone::Session#execute` never touches `variable`), so the finishing
  #     variable still matches, the chart is still evaluated, and - the question variables
  #     matching too - the participant is charted on the OTHER intervention's chart with
  #     their own data. Hand-named collisions are untouched for the same reason. This job is
  #     "closed only halfway" (`summary.md`); the residual is a recorded trade-off, not an
  #     oversight.
  #
  # The May 2026 branched-questions fix considered this exact refactor and declined it
  # BECAUSE the never-reached guard made it unnecessary
  # (.claude/cias-api/plans/fixes/fix-chart-statistics-branched-questions.md:26) - the
  # premise this change removes.
  def charts
    organization_charts.select { |chart| chart_session_variables(chart).include?(finishing_session_variable) }
  end

  def organization_charts
    Chart.joins(dashboard_section: [reporting_dashboard: :organization]).where(
      dashboard_sections: { reporting_dashboards: { organization: organization } }
    )
  end

  def finishing_session_variable
    @finishing_session_variable ||= user_session.session.variable
  end

  # The `session_variable` half of each `session_variable.question_variable` token, exactly
  # as the replay path extracts it.
  #
  # The `formula` guard is not defensive noise: `charts.formula` is DB-nullable and
  # `payload` is only schema-required on write, so a legacy chart can carry neither, and
  # `Chart#formula_variables` tolerates both (chart.rb:60). Raising here would escape
  # `call`'s per-chart `rescue` and take the participant's whole session finish with it.
  # A chart with no `session_variable.question_variable` token - a blank payload, or bare
  # unqualified variable names - matches no session and is skipped, which is also what the
  # replay path does with it (`sessions.variable IN ()` matches nothing).
  def chart_session_variables(chart)
    return [] unless chart.formula.is_a?(Hash) && chart.formula['payload'].is_a?(String)

    chart.chart_variables.map { |variable| variable.split('.').first }
  end
end
