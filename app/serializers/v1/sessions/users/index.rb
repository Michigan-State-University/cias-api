# frozen_string_literal: true

class V1::Sessions::Users::Index < BaseSerializer
  def cache_key
    "sessions/users/#{@user_sessions.count}-#{@user_sessions.maximum(:updated_at)&.to_s(:number)}"
  end

  def to_json
    { user_sessions: collect_user_sessions }
  end

  private

  def collect_user_sessions
    @user_sessions.map do |user_inter|
      V1::Sessions::Users::Show.new(user_session: user_inter).to_json
    end
  end
end
