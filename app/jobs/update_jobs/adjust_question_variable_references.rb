# frozen_string_literal: true

class UpdateJobs::AdjustQuestionVariableReferences < UpdateJobs::VariableReferencesUpdateJob
  def perform(question_id, old_variable_name, new_variable_name)
    return if old_variable_name == new_variable_name
    return if old_variable_name.blank? || new_variable_name.blank?

    question = Question.find(question_id)
    source_session = question.question_group.session
    intervention_id = source_session.intervention_id

    with_formula_update_lock(intervention_id) do
      ActiveRecord::Base.transaction do
        # Phase 1: Update direct variable references in source session
        update_question_formulas_scoped(source_session, old_variable_name, new_variable_name, exclude_source_session: false)
        update_question_narrator_formulas_scoped(source_session, old_variable_name, new_variable_name, exclude_source_session: false)
        update_question_narrator_reflection_variables_scoped(source_session, old_variable_name, new_variable_name, exclude_source_session: false)
        update_session_formulas_scoped(source_session, old_variable_name, new_variable_name, exclude_source_session: false)
        update_question_group_formulas_scoped(source_session, old_variable_name, new_variable_name, exclude_source_session: false)
        update_report_template_formulas_scoped(source_session, old_variable_name, new_variable_name, exclude_source_session: false)

        # Phase 2: Update cross-session references (session_var.old_question_var -> session_var.new_question_var)
        source_session_var = source_session.variable
        old_cross_session_pattern = "#{source_session_var}.#{old_variable_name}"
        new_cross_session_pattern = "#{source_session_var}.#{new_variable_name}"

        update_question_formulas_scoped(source_session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
        update_session_formulas_scoped(source_session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
        update_question_group_formulas_scoped(source_session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
        update_question_narrator_formulas_scoped(source_session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
        update_question_narrator_reflection_variables_scoped(source_session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
        update_report_template_formulas_scoped(source_session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
        update_chart_formulas(intervention_id, old_cross_session_pattern, new_cross_session_pattern)

        Rails.logger.info "[#{self.class.name}] Job completed successfully"
      end
    end
  end
end
