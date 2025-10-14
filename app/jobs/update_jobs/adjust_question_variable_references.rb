# frozen_string_literal: true

class UpdateJobs::AdjustQuestionVariableReferences < UpdateJobs::VariableReferencesUpdateJob
  def perform(question_id, old_variable_name, new_variable_name)
    @question_id = question_id
    @old_variable_name = old_variable_name
    @new_variable_name = new_variable_name

    return if old_variable_name == new_variable_name
    return if old_variable_name.blank? || new_variable_name.blank?
    return if question.question_variables.first == new_variable_name

    with_formula_update_lock(source_session.intervention_id) do
      ActiveRecord::Base.transaction do
        update_direct_variable_references
        update_cross_session_variable_references
        Rails.logger.info "[#{self.class.name}] Job completed successfully"
      end
    end
  end

  private

  def question
    @question ||= Question.find(@question_id)
  end

  def source_session
    @source_session ||= question.session
  end

  def old_cross_session_pattern
    @old_cross_session_pattern ||= "#{source_session.variable}.#{@old_variable_name}"
  end

  def new_cross_session_pattern
    @new_cross_session_pattern ||= "#{source_session.variable}.#{@new_variable_name}"
  end

  def update_direct_variable_references
    update_question_formulas_scoped(source_session, @old_variable_name, @new_variable_name, exclude_source_session: false)
    update_question_narrator_formulas_scoped(source_session, @old_variable_name, @new_variable_name, exclude_source_session: false)
    update_question_narrator_reflection_variables_scoped(source_session, @old_variable_name, @new_variable_name, exclude_source_session: false)
    update_question_group_formulas_scoped(source_session, @old_variable_name, @new_variable_name, exclude_source_session: false)
    update_session_formulas_scoped(source_session, @old_variable_name, @new_variable_name, exclude_source_session: false)
    update_report_template_formulas_scoped(source_session, @old_variable_name, @new_variable_name, exclude_source_session: false)
  end

  def update_cross_session_variable_references
    update_question_formulas_scoped(source_session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
    update_question_narrator_formulas_scoped(source_session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
    update_question_narrator_reflection_variables_scoped(source_session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
    update_question_group_formulas_scoped(source_session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
    update_session_formulas_scoped(source_session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
    update_report_template_formulas_scoped(source_session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
    update_chart_formulas(source_session.intervention_id, old_cross_session_pattern, new_cross_session_pattern)
  end
end
