# frozen_string_literal: true

class UserSession < ApplicationRecord
  belongs_to :user, inverse_of: :user_sessions
  belongs_to :session, inverse_of: :user_sessions

  before_save :alter_schedule

  def alter_schedule
    return if session == session_next
    return if session_next&.schedule.nil?
    return unless session_next&.schedule_days_after_fill?
    return if submitted_at.nil?

    Session::Schedule.new(
      self,
      session_next,
      user_session_next
    ).days_after_fill
  end

  private

  def session_next
    @session_next ||= session.position_grather_than.first
  end

  def user_session_next
    @user_session_next ||= session_next.user_sessions.find_by(user_id: user_id)
  end
end
