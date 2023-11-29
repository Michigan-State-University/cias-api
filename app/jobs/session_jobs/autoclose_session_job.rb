# frozen_string_literal: true

class SessionJobs::AutocloseSessionJob < SessionJob
  def perform(session_id)
    UserSession.where(session_id: session_id, finished_at: nil).find_each(&:finish)
  end
end
