# frozen_string_literal: true

class V1::UserSessions::ChartStatistics::Create
  def self.call(user_session)
    new(user_session).call
  end

  def initialize(user_session)
    @user_session = user_session
  end

  def call
    return unless intervention.published?
    return unless organization

    charts.each do |chart|
      next unless chart.published_at

      V1::ChartStatistics::Create.call(chart, user_session, organization)
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

  def charts
    Chart.joins(dashboard_section: [reporting_dashboard: :organization]).where(
      dashboard_sections: { reporting_dashboards: { organization: organization } }
    )
  end
end
