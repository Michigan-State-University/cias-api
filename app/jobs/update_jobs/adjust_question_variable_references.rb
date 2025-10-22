# frozen_string_literal: true

class UpdateJobs::AdjustQuestionVariableReferences < UpdateJobs::VariableReferencesUpdateJob
  def perform(question_id, old_variable_name, new_variable_name)
    return if old_variable_name == new_variable_name
    return if old_variable_name.blank? || new_variable_name.blank?

    question = Question.find(question_id)

    with_formula_update_lock(question.session.intervention_id) do
      V1::VariableReferences::QuestionService.call(
        question_id,
        old_variable_name,
        new_variable_name
      )
    end
  end
end
