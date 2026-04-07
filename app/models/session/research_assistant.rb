# frozen_string_literal: true

class Session::ResearchAssistant < Session
  include ::Session::ClassicBehavior

  validate :single_ra_session_per_intervention, on: :create
  validate :position_must_be_zero
  validate :no_cross_session_branching
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

  def no_cross_session_branching
    return if formulas.blank?

    formulas.each do |formula|
      formula['patterns']&.each do |pattern|
        pattern['target']&.each do |target|
          if target['type']&.include?('Session') && target['id'].present?
            errors.add(:formulas, :ra_session_cannot_branch_to_other_sessions)
          end
        end
      end
    end
  end
end
