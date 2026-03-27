# frozen_string_literal: true

class Session::ResearchAssistant < Session
  include Session::ClassicBehavior

  validate :single_ra_session_per_intervention, on: :create
  validate :position_must_be_zero
  validates :sms_plans, absence: true
  before_validation :force_single_fill

  def user_session_type
    UserSession::ResearchAssistant.name
  end

  private

  def force_single_fill
    self.multiple_fill = false
  end

  def single_ra_session_per_intervention
    return unless intervention&.sessions&.where(type: 'Session::ResearchAssistant')
                               &.where&.not(id: id)&.exists?

    errors.add(:base, :only_one_ra_session_allowed)
  end

  def position_must_be_zero
    errors.add(:position, :must_be_zero) unless position&.zero?
  end
end
