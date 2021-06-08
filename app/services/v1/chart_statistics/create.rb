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
    return if dentaku_service.exist_missing_variables?

    ChartStatistic.find_or_create_by!(
      label: label,
      organization: organization,
      health_system: health_system,
      health_clinic: health_clinic,
      chart: chart,
      user: user_session.user
    )
  end

  private

  attr_reader :chart, :user_session, :organization

  def label
    result = dentaku_service.calculate

    if chart.chart_type == Chart.chart_types[:bar_chart]
      result ? 'Matched' : 'NotMatched'
    else
      result ? result['label'] : chart.formula['default_pattern']['label']
    end
  end

  def dentaku_service
    @dentaku_service ||= Calculations::DentakuService.new(
      all_var_values, formula['payload'], formula['patterns'], true
    )
  end

  def formula
    chart.formula
  end

  def all_var_values
    V1::UserInterventionService.new(
      user_session.user.id, user_session.session.intervention_id, nil
    ).var_values
  end

  def health_system
    health_clinic.health_system
  end

  def health_clinic
    user_session.health_clinic
  end
end
