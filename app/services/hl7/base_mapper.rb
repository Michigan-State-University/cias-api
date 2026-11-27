# frozen_string_literal: true

class Hl7::BaseMapper
  attr_reader :user_session

  def initialize(user_session_id)
    @user_session = UserSession.find(user_session_id)
  end

  protected

  def report_timezone
    Ehr::Settings.hl7_report_timezone
  end
end
