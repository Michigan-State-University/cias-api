# frozen_string_literal: true

class GeneratedReportFinder
  def self.search(filter_params, current_user)
    new(filter_params, current_user).search
  end

  def initialize(filter_params, current_user)
    @filter_params = filter_params
    @current_user = current_user
    @scope = GeneratedReport.accessible_by(current_user.ability)
  end

  def search
    scope = filter_for_session
    scope.then { |reports| filter_report_for(reports) }
  end

  private

  attr_reader :filter_params, :current_user, :scope

  def filter_report_for(reports)
    return GeneratedReport.none if filter_params[:report_for].blank?

    reports.where(report_for: filter_params[:report_for])
  end

  def filter_for_session
    return scope if filter_params[:session_id].blank?

    scope.joins(:user_session).where(user_sessions: { session_id: filter_params[:session_id] })
  end
end
