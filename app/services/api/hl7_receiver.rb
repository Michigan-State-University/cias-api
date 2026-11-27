# frozen_string_literal: true

class Api::Hl7Receiver
  def send_answers(user_session_id)
    Api::Hl7Receiver::UserSession.call(user_session_id)
  end

  def send_reports(user_session_id)
    Api::Hl7Receiver::Reports.call(user_session_id)
  end
end
