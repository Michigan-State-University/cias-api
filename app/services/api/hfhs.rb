# frozen_string_literal: true

class Api::Hfhs
  def send_answers(user_session_id)
    Api::Hfhs::UserSession.call(user_session_id)
  end

  def send_reports(user_session_id)
    Api::Hfhs::Reports.call(user_session_id)
  end
end
