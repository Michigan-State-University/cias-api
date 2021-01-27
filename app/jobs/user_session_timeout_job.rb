# frozen_string_literal: true

class UserSessionTimeoutJob < ApplicationJob
  queue_as :default

  def perform(user_session_id)
    user_session = UserSession.find_by(id: user_session_id)
    user_session&.finish
  end
end
