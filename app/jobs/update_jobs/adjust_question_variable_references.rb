# frozen_string_literal: true

class UpdateJobs::AdjustQuestionVariableReferences < CloneJob
  include VariableReferencesLockManagement

  def perform(question_id, old_variable_name, new_variable_name)
    @question_id = question_id
    question = Question.find_by(id: question_id)

    if question.nil?
      Rails.logger.warn "[#{self.class.name}] Skipping job, Question with ID #{question_id} not found."
      return
    end

    with_formula_update_lock(question.session.intervention_id) do
      next if old_variable_name == new_variable_name
      next if old_variable_name.blank? || new_variable_name.blank?

      V1::VariableReferences::QuestionService.call(
        question_id,
        old_variable_name,
        new_variable_name
      )
    end
  end

  private

  def session_id_for_lock_cleanup
    question = Question.find_by(id: @question_id)
    question&.session&.id
  end
end
