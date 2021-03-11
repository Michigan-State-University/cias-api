# frozen_string_literal: true

class GeneratedReportFinder
  def self.search(filter_params, current_user, session_param)
    new(filter_params, current_user, session_param).search
  end

  def initialize(filter_params, current_user, session_param)
    @filter_params = filter_params || {}
    @session_param = session_param || {}
    @current_user = current_user
    @scope = GeneratedReport.accessible_by(current_user.ability)
    @scope = @scope.joins(:user_session).where(user_sessions: {session_id: session_param[:session_id]}) if not session_param.blank?
  end

  def search
    scope.then { |reports| filter_report_for(reports) }
  end

  private

  attr_reader :filter_params, :current_user, :scope

  def filter_report_for(reports)
    return GeneratedReport.none if filter_params[:report_for].blank?

    reports.where(report_for: filter_params[:report_for])
  end
end
