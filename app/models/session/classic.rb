# frozen_string_literal: true

class Session::Classic < Session
  include ::Session::ClassicBehavior

  def user_session_type
    UserSession::Classic.name
  end
end
