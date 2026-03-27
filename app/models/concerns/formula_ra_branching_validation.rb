# frozen_string_literal: true

module FormulaRaBranchingValidation
  extend ActiveSupport::Concern

  included do
    validate :no_cross_session_branching_from_ra
    validate :no_branching_to_ra_session
  end

  private

  def no_cross_session_branching_from_ra
    return unless session&.type == 'Session::ResearchAssistant'
    return if formulas.blank?

    formulas.each do |formula|
      formula['patterns']&.each do |pattern|
        pattern['target']&.each do |target|
          if target['type']&.include?('Session') && target['id'].present?
            errors.add(:formulas, :ra_cannot_branch_to_other_sessions)
          end
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
          if target_session&.type == 'Session::ResearchAssistant'
            errors.add(:formulas, :cannot_branch_to_ra_session)
          end
        end
      end
    end
  end
end
