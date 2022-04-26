# frozen_string_literal: true

class SessionJobs::ReloadAudio < SessionJob
  def perform(session_id)
    Session.find(session_id).questions.each(&:execute_narrator) if Session.exists?(session_id)
  end
end
