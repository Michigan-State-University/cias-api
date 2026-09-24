# frozen_string_literal: true

class UserSessionTimeoutJob < ApplicationJob
  queue_as :default

  def perform(user_session_id, reason = 'completed')
    user_session = UserSession.find_by(id: user_session_id)
    return if user_session.nil?

    if reason == 'inactivity_timeout' && !user_session.inactivity_elapsed?
      user_session.rearm_inactivity_timeout
      return
    end

    reason == 'completed' ? user_session.finish : user_session.finish(reason: reason)
  end
end
