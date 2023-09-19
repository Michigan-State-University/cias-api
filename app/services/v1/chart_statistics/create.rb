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
    return if dentaku_service.exist_missing_variables?
    return if zero_division_error?
    return unless inside_date_range?

    ChartStatistic.find_or_create_by!(
      label: label,
      organization: organization,
      health_system: health_system,
      health_clinic: health_clinic,
      chart: chart,
      user: user_session.user,
      filled_at: user_session.finished_at || DateTime.current
    )
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
    V1::UserInterventionService.new(
      user_session.user_intervention_id, nil
    ).var_values
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

  def inside_date_range?
    return false if chart.date_range_start.present? && chart.date_range_start > user_session.finished_at
    # +1.day because FE sends and BE stores the BEGINNING of the last day, and we need to include this day as a whole as well
    return false if chart.date_range_end.present? && chart.date_range_end + 1.day <= user_session.finished_at

    true
  end
end
