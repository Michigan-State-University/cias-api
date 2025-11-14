# frozen_string_literal: true

class UpdateJobs::AdjustQuestionAnswerOptionsReferences < CloneJob
  def perform(question_id, changed_answer_values, new_answer_options = {}, deleted_answer_options = {}, grid_columns = {})
    changed_columns = grid_columns[:changed] || {}
    new_columns = grid_columns[:new] || {}
    deleted_columns = grid_columns[:deleted] || {}

    if changed_answer_values.blank? && new_answer_options.blank? &&
       deleted_answer_options.blank? && changed_columns.blank? &&
       new_columns.blank? && deleted_columns.blank?
      return
    end

    question = Question.find_by(id: question_id)
    return if question.nil?

    V1::VariableReferences::AnswerOptionsService.call(
      question_id,
      changed_answer_values,
      new_answer_options,
      deleted_answer_options,
      {
        changed: changed_columns,
        new: new_columns,
        deleted: deleted_columns
      }
    )
    Rails.logger.debug '[AdjustQuestionAnswerOptionsReferences] Job completed successfully'
  end
end
