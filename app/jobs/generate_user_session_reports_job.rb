# frozen_string_literal: true

class GenerateUserSessionReportsJob < ApplicationJob
  queue_as :reports

  def perform(user_session_id)
    V1::GeneratedReports::GenerateUserSessionReports.call(
      UserSession.find(user_session_id)
    )
  end
end
