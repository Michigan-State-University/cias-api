# frozen_string_literal: true

class GenerateUserSessionReportsJob < ApplicationJob
  queue_as :reports

  def perform(user_session_id)
    user_session = UserSession.find_by(id: user_session_id)
    return if user_session.blank?

    V1::GeneratedReports::GenerateUserSessionReports.call(user_session)
  end
end
