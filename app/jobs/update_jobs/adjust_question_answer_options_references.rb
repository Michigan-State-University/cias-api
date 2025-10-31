# frozen_string_literal: true

class UpdateJobs::AdjustQuestionAnswerOptionsReferences < UpdateJobs::VariableReferencesUpdateJob
  def perform(question_id, changed_answer_values)
    return if changed_answer_values.blank?

    question = Question.find_by(id: question_id)
    if question.nil?
      Rails.logger.warn "[#{self.class.name}] Skipping job, Question with ID #{question_id} not found."
      return
    end

    intervention_id = question.session&.intervention_id
    if intervention_id.blank?
      Rails.logger.warn "[#{self.class.name}] Skipping job, Question #{question.id} has no valid Intervention ID to lock."
      return
    end

    with_formula_update_lock(intervention_id) do
      V1::VariableReferences::AnswerOptionsService.call(
        question_id,
        changed_answer_values
      )
    end
  end
end
