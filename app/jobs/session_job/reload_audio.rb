# frozen_string_literal: true

class SessionJob::ReloadAudio < SessionJob
  def perform(session_id)
    Session.find(session_id).questions.each(&:execute_narrator)
  end
end
