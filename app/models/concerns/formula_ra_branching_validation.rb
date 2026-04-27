# frozen_string_literal: true

module FormulaRaBranchingValidation
  extend ActiveSupport::Concern

  included do
    validate :no_cross_session_branching_from_ra
    validate :no_branching_to_ra_session
  end

  private

  def no_cross_session_branching_from_ra
    return unless ra_branching_session_type == 'Session::ResearchAssistant'
    return if formulas.blank?

    formulas.each do |formula|
      formula['patterns']&.each do |pattern|
        pattern['target']&.each do |target|
          errors.add(:formulas, :ra_cannot_branch_to_other_sessions) if target['type']&.include?('Session') && target['id'].present?
        end
      end
    end
  end

  def no_branching_to_ra_session
    return if formulas.blank?

    formulas.each do |formula|
      formula['patterns']&.each do |pattern|
        pattern['target']&.each do |target|
          next unless target['type']&.include?('Session') && target['id'].present?

          target_session = Session.find_by(id: target['id'])
          errors.add(:formulas, :cannot_branch_to_ra_session) if target_session&.type == 'Session::ResearchAssistant'
        end
      end
    end
  end

  # Question reaches session via a `:session` delegate that raises on nil question_group; QuestionGroup has session directly.
  def ra_branching_session_type
    if respond_to?(:question_group)
      question_group&.session&.type
    else
      session&.type
    end
  end
end
