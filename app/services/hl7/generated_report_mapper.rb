# frozen_string_literal: true

class Hl7::GeneratedReportMapper
  def self.call(user_session_id, report_id)
    new(user_session_id, report_id).call
  end

  def initialize(user_session_id, report_id)
    @user_session = UserSession.find(user_session_id)
    @report_id = report_id
  end

  def call
    [
      Hl7::PatientDataMapper.call(user_session.user.id, user_session.id),
      Hl7::ReportMapper.call(report_id, user_session.id)
    ].flatten
  end

  attr_reader :user_session, :report_id
end
