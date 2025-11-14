# frozen_string_literal: true

class UpdateJobs::AdjustQuestionVariableReferences < UpdateJobs::VariableReferencesUpdateJob
  def perform(question_id, old_variable_name, new_variable_name)
    Rails.logger.info "[#{self.class.name}] Starting job for question #{question_id}: '#{old_variable_name}' -> '#{new_variable_name}'"

    question = Question.find_by(id: question_id)

    if question.nil?
      Rails.logger.warn "[#{self.class.name}] Skipping job, Question with ID #{question_id} not found."
      return
    end

    with_formula_update_lock(question.session.id) do
      next if old_variable_name == new_variable_name
      next if old_variable_name.blank? || new_variable_name.blank?

      V1::VariableReferences::QuestionService.call(
        question_id,
        old_variable_name,
        new_variable_name
      )
    end
  end
end
