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

  def chart_session_variables(chart)
    return [] unless chart.formula.is_a?(Hash) && chart.formula['payload'].is_a?(String)

    chart.chart_variables.map { |variable| variable.split('.').first }
  end
end
