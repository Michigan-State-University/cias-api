# frozen_string_literal: true

class V1::ChartStatistics::CreateForUserSessions
  def self.call(chart_id)
    new(chart_id).call
  end

  def initialize(chart_id)
    @chart_id = chart_id
  end

  def call
    # service should be run when the chart is published
    user_sessions.each do |user_session|
      next unless user_session.session.intervention.published?

      V1::ChartStatistics::Create.call(chart, user_session, organization)
    end
  end

  private

  attr_reader :chart_id

  def user_sessions
    UserSession.joins(session: [intervention: :organization]).where(
      sessions: { interventions: { organization: organization } }
    )
  end

  def organization
    @organization ||= chart.dashboard_section.reporting_dashboard.organization
  end

  def chart
    @chart ||= Chart.find(chart_id)
  end
end
