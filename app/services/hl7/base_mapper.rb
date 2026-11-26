# frozen_string_literal: true

class Hl7::BaseMapper
  attr_reader :user_session

  def initialize(user_session_id)
    @user_session = UserSession.find(user_session_id)
  end

  protected

  # A blank setting falls back to the participant's time zone (in_time_zone('') would raise).
  def report_timezone
    Ehr::Settings.fetch('HL7_REPORT_TIMEZONE') || user_session&.user&.time_zone
  end
end
