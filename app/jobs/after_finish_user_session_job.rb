# frozen_string_literal: true

class AfterFinishUserSessionJob < ApplicationJob
  queue_as :default

  def perform(user_session_id, intervention)
    V1::GeneratedReports::GenerateUserSessionReports.call(
      UserSession.find(user_session_id)
    )

    Hfhs::SendAnswersJob.perform_later(user_session_id) if intervention.hfhs_access?
  end
end
