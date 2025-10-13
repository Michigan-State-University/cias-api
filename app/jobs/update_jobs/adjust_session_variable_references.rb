# frozen_string_literal: true

class UpdateJobs::AdjustSessionVariableReferences < UpdateJobs::VariableReferencesUpdateJob
  def perform(session_id, old_session_variable, new_session_variable)
    return if old_session_variable == new_session_variable
    return if old_session_variable.blank? || new_session_variable.blank?

    session = Session.find(session_id)
    intervention_id = session.intervention_id

    with_formula_update_lock(intervention_id) do
      question_variables = extract_question_variables_from_session(session)

      ActiveRecord::Base.transaction do
        patterns_to_update = [old_session_variable] + question_variables.map { |var| "#{old_session_variable}.#{var}" }
        new_patterns = [new_session_variable] + question_variables.map { |var| "#{new_session_variable}.#{var}" }

        patterns_to_update.zip(new_patterns).each do |old_pattern, new_pattern|
          update_question_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: true)
          update_session_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: true)
          update_question_group_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: true)
          update_report_template_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: true)
          update_chart_formulas(intervention_id, old_pattern, new_pattern)
        end
      end
    end
  end

  private

  def extract_question_variables_from_session(session)
    sql = <<~SQL.squish
      WITH session_questions AS (
        SELECT q.type, q.body
        FROM questions q
        JOIN question_groups qg ON q.question_group_id = qg.id
        WHERE qg.session_id = $1
      )
      SELECT DISTINCT variable_name
      FROM (
        SELECT body->'variable'->>'name' as variable_name
        FROM session_questions
        WHERE type = 'Question::Single'
        AND body->'variable'->>'name' IS NOT NULL

        UNION

        SELECT data_item->'variable'->>'name' as variable_name
        FROM session_questions, jsonb_array_elements(body->'data') as data_item
        WHERE type = 'Question::Multiple'
        AND data_item->'variable'->>'name' IS NOT NULL

        UNION

        SELECT row_item->'variable'->>'name' as variable_name
        FROM session_questions,
             jsonb_array_elements(body->'data'->0->'payload'->'rows') as row_item
        WHERE type = 'Question::Grid'
        AND row_item->'variable'->>'name' IS NOT NULL
      ) AS variables
      WHERE variable_name != '' AND variable_name IS NOT NULL
    SQL

    result = ActiveRecord::Base.connection.exec_query(sql, 'SQL', [session.id])
    result.rows.flatten.compact
  end
end
