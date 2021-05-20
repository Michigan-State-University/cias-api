# frozen_string_literal: true

class V1::Charts::ChartStatistics::Create
  def self.call(chart_id)
    new(chart_id).call
  end

  def initialize(chart_id)
    @chart_id = chart_id
  end

  def call
    user_sessions.each do |user_session|
      user = user_session.user
      dentaku_service = initialize_dentaku_service(user_session, user)
      next if dentaku_service.exist_missing_variables?

      label = calculate_label(dentaku_service)
      health_clinic = user_session.health_clinic
      health_system = health_clinic.health_system

      create_chart_statistic(label, user, health_clinic, health_system)
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

  def formula
    chart.formula
  end

  def initialize_dentaku_service(user_session, user)
    all_var_values = V1::UserInterventionService.new(
      user.id, user_session.session.intervention_id, user_session.id
    ).var_values
    Calculations::DentakuService.new(all_var_values, formula['payload'], formula['patterns'], true)
  end

  def calculate_label(dentaku_service)
    result = dentaku_service.calculate

    if chart.chart_type == Chart.chart_types[:bar_chart]
      result ? 'Matched' : 'NotMatched'
    else
      result ? result['label'] : formula['default_pattern']['label']
    end
  end

  def create_chart_statistic(label, user, health_clinic, health_system)
    ChartStatistic.find_or_create_by!(
      label: label,
      organization: organization,
      health_system: health_system,
      health_clinic: health_clinic,
      chart: chart,
      user: user
    )
  end
end
