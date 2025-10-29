# frozen_string_literal: true

class UpdateJobs::AdjustQuestionAnswerValues < UpdateJobs::VariableReferencesUpdateJob
  def perform(question_id, changed_answer_values)
    Rails.logger.info "[#{self.class.name}] Starting job for question_id: #{question_id}, changes: #{changed_answer_values.inspect}"

    return if changed_answer_values.blank?

    question = Question.find(question_id)

    if question.nil?
      Rails.logger.warn "[#{self.class.name}] Skipping job, Question with ID #{question_id} not found."
      return
    end

    Rails.logger.info "[#{self.class.name}] Found question: #{question.id} (#{question.title}), proceeding with update"

    with_formula_update_lock(question.session.intervention_id) do
      V1::VariableReferences::AnswerValuesService.call(
        question_id,
        changed_answer_values
      )
    end

    Rails.logger.info "[#{self.class.name}] Job completed successfully for question_id: #{question_id}"
  end
end
