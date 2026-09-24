# frozen_string_literal: true

class AfterFinishUserSessionJob < ApplicationJob
  queue_as :session_finish

  def perform(user_session_id, intervention, reason = 'completed')
    V1::GeneratedReports::GenerateUserSessionReports.call(
      UserSession.find(user_session_id)
    )

    return if reason == 'inactivity_timeout'

    Hfhs::SendAnswersJob.perform_later(user_session_id) if intervention.hfhs_access?
  end
end
