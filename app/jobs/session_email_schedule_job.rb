# frozen_string_literal: true

class SessionEmailScheduleJob < ApplicationJob
  queue_as :default

  def perform(session_id, user_id, health_clinic_id = nil)
    session = Session.find_by(id: session_id)
    user = User.find_by(id: user_id)
    session&.send_link_to_session(user, health_clinic_id) if user
  end
end
