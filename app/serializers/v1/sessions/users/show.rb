# frozen_string_literal: true

class V1::Sessions::Users::Show < BaseSerializer
  def cache_key
    "sessions/user/#{@user_session.id}-#{@user_session.updated_at&.to_s(:number)}"
  end

  def to_json
    {
      id: @user_session.id,
      user_id: @user_session.user_id,
      email: @user_session.user.email,
      session_id: @user_session.session_id,
      submitted_at: @user_session.submitted_at,
      schedule_at: @user_session.schedule_at
    }
  end
end
