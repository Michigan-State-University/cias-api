# frozen_string_literal: true

class V1::Sessions::Users::IndexUsersUniq < BaseSerializer
  def cache_key
    "sessions/index-users-uniq/#{user_sessions.count}-#{user_sessions.maximum(:updated_at)&.to_s(:number)}"
  end

  def to_json
    { user_sessions: collect_user_sessions }
  end

  private

  attr_reader :user_sessions

  def collect_user_sessions
    user_sessions.joins(:user).select(:user_id).distinct.map do |user_inter|
      {
        user_id: user_inter.user_id,
        email: user_inter.user.email
      }
    end
  end
end
