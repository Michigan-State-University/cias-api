# frozen_string_literal: true

class Session::ResearchAssistant < Session
  include ::Session::ClassicBehavior

  SUPPORTED_QUESTION_TYPES = %w[Question::Single Question::Number Question::Date].freeze

  validate :single_ra_session_per_intervention, on: :create
  validate :position_must_be_zero
  validate :no_cross_session_branching
  before_validation :force_single_fill
  before_destroy :log_ra_deletion_impact, prepend: true, if: -> { user_sessions.where.not(finished_at: nil).exists? }

  def user_session_type
    UserSession::ResearchAssistant.name
  end

  private

  def force_single_fill
    self.multiple_fill = false
  end

  def set_default_variable
    return if variable.present?

    candidate = 'ra'
    index = 1
    while ::Session.where.not(id: id).where(intervention: intervention).exists?(variable: candidate)
      candidate = "ra_#{index}"
      index += 1
    end
    self.variable = candidate
  end

  def single_ra_session_per_intervention
    return unless intervention&.sessions&.where(type: 'Session::ResearchAssistant')
                               &.where&.not(id: id)&.exists?

    errors.add(:base, :only_one_ra_session_allowed)
  end

  def position_must_be_zero
    errors.add(:position, :must_be_zero) unless position&.zero?
  end

  def log_ra_deletion_impact
    completed_count = user_sessions.where.not(finished_at: nil).count
    Rails.logger.warn(
      "RA session #{id} deleted with #{completed_count} completed user sessions. " \
      'All PDP participants will be unblocked.'
    )
  end

  def no_cross_session_branching
    return if formulas.blank?

    formulas.each do |formula|
      formula['patterns']&.each do |pattern|
        pattern['target']&.each do |target|
          errors.add(:formulas, :ra_session_cannot_branch_to_other_sessions) if target['type']&.include?('Session') && target['id'].present?
        end
      end
    end
  end
end
