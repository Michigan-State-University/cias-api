# frozen_string_literal: true

class UserSession < ApplicationRecord
  belongs_to :user, inverse_of: :user_sessions
  belongs_to :session, inverse_of: :user_sessions
  has_many :answers, dependent: :destroy

  def finished
    session_next&.queue_to_schedule
  end

  private

  def session_next
    @session_next ||= session.position_grather_than.first
  end
end
