# frozen_string_literal: true

class Hl7::BaseMapper
  attr_reader :user_session

  def initialize(user_session_id)
    @user_session = UserSession.find(user_session_id)
  end

  protected

  def report_timezone
    ENV.fetch('HFH_REPORT_TIMEZONE', nil) || user_session&.user&.time_zone
  end
end
