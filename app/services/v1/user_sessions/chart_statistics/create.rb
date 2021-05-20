# frozen_string_literal: true

class V1::UserSessions::ChartStatistics::Create
  def self.call(user_session)
    new(user_session).call
  end

  def initialize(user_session)
    @user_session = user_session
  end

  def call
    return unless organization

    charts.each do |chart|
      next unless chart.published_at

      dentaku_service = initialize_dentaku_service(chart.formula)
      next if dentaku_service.exist_missing_variables?

      label = calculate_label(dentaku_service, chart.chart_type, chart.formula)
      create_chart_statistic(chart, label)
    end
  end

  private

  attr_reader :user_session

  def calculate_label(dentaku_service, chart_type, formula)
    result = dentaku_service.calculate

    if chart_type == Chart.chart_types[:bar_chart]
      result ? 'Matched' : 'NotMatched'
    else
      result ? result['label'] : formula['default_pattern']['label']
    end
  end

  def create_chart_statistic(chart, label)
    ChartStatistic.find_or_create_by!(
      label: label,
      organization: organization,
      health_system: health_system,
      health_clinic: health_clinic,
      chart: chart,
      user: user
    )
  end

  def initialize_dentaku_service(formula)
    Calculations::DentakuService.new(all_var_values, formula['payload'], formula['patterns'], true)
  end

  def session
    @session ||= user_session.session
  end

  def organization
    @organization ||= session.intervention.organization
  end

  def health_system
    @health_system ||= health_clinic.health_system
  end

  def health_clinic
    @health_clinic ||= user_session.health_clinic
  end

  def charts
    Chart.joins(dashboard_section: [reporting_dashboard: :organization]).where(
      dashboard_sections: { reporting_dashboards: { organization: organization } }
    )
  end

  def user
    @user ||= user_session.user
  end

  def all_var_values
    V1::UserInterventionService.new(user.id, user_session.session.intervention_id, user_session.id).var_values
  end
end
