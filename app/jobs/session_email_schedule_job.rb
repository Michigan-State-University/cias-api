# frozen_string_literal: true

class SessionEmailScheduleJob < ApplicationJob
  queue_as :default

  def perform(session_id, user_id)
    session = Session.find_by(id: session_id)
    user = User.find_by(id: user_id)
    session&.send_link_to_session(user) if user
  end
end
