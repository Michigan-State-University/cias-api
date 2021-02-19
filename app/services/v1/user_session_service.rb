# frozen_string_literal: true

class V1::UserSessionService
  def initialize(user)
    @user = user
  end

  attr_reader :user

  def create(user_session_parms)
    session_id = user_session_parms['session_id']
    UserSession.find_or_create_by!(session_id: session_id, user_id: user.id)
  end
end
