# frozen_string_literal: true

class V1::ChartStatistics::CreateForUserSessions
  def self.call(chart_id)
    new(chart_id).call
  end

  def initialize(chart_id)
    @chart_id = chart_id
  end

  def call
    # service should be run when the chart is published/data_collection
    user_sessions.each do |user_session|
      next if user_session.session.intervention.draft?

      V1::ChartStatistics::Create.call(chart, user_session, organization)
    end
  end

  private

  attr_reader :chart_id

  def user_sessions
    UserSession.joins(session: [intervention: :organization]).where(
      sessions: {
        interventions: { organization: organization },
        variable: chart_session_variables
      }
    ).where.not(finished_at: nil)
  end

  def organization
    @organization ||= chart.dashboard_section.reporting_dashboard.organization
  end

  def chart
    @chart ||= Chart.find(chart_id)
  end

  def chart_session_variables
    chart.chart_variables.map {|variable| variable.split('.').first}
  end
end
