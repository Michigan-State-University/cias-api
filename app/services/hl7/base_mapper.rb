# frozen_string_literal: true

class Hl7::BaseMapper
  attr_reader :user_session

  def initialize(user_session_id)
    @user_session = UserSession.find(user_session_id)
  end

  protected

  def report_timezone
    Ehr::Settings.fetch('HL7_REPORT_TIMEZONE') || user_session&.user&.time_zone
  end
end
