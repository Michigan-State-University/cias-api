# frozen_string_literal: true

class UserSession::CatMh < UserSession
  def on_answer
    update(last_answer_at: DateTime.current)
  end
end
