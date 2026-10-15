# frozen_string_literal: true

class V1::VariableReferences::SessionService < V1::VariableReferences::BaseService
  # include_source_session is NOT the QueryBuilder flag of the near-identical name: that one is
  # either/or, so covering a whole intervention means running both of its passes.
  def initialize(session_id, old_session_variable, new_session_variable, include_source_session: false, skip_chart_formulas: false)
    super()
    @session_id = session_id
    @old_session_variable = old_session_variable
    @new_session_variable = new_session_variable
    @include_source_session = include_source_session
    @skip_chart_formulas = skip_chart_formulas
  end

  def call
    return if @old_session_variable == @new_session_variable
    return if @old_session_variable.blank? || @new_session_variable.blank?

    ActiveRecord::Base.transaction do
      patterns_to_update.zip(new_patterns).each do |old_pattern, new_pattern|
        update_variable_references(old_pattern, new_pattern)
      end
      update_days_after_date_session_variable_references(@old_session_variable, @new_session_variable)
      Rails.logger.info "[#{self.class.name}] Service completed successfully for session_id: #{@session_id}"
    end
  end

  private

  def session
    @session ||= Session.find(@session_id)
  end

  def question_variables
    @question_variables ||= extract_question_variables_from_session(session)
  end

  def patterns_to_update
    @patterns_to_update ||= [@old_session_variable]
  end

  def new_patterns
    @new_patterns ||= [@new_session_variable]
  end

  # A session variable only ever appears as the `svar.` prefix, never standalone. The trailing (\w)
  # keeps `baseline.phq` in scope and leaves a sentence-ending "your baseline." alone.
  def variable_regex(old_var)
    "\\m#{Regexp.escape(old_var)}\\.(\\w)"
  end

  def variable_replacement(new_var)
    "#{escape_regexp_replacement(new_var)}.\\1"
  end

  def update_variable_references(old_pattern, new_pattern)
    source_session_modes.each do |exclude_source_session|
      update_scoped_carriers(old_pattern, new_pattern, exclude_source_session)
    end
    update_chart_formulas(session.intervention_id, old_pattern, new_pattern) unless @skip_chart_formulas
  end

  def update_scoped_carriers(old_pattern, new_pattern, exclude_source_session)
    update_question_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: exclude_source_session)
    update_question_narrator_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: exclude_source_session)
    update_question_group_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: exclude_source_session)
    update_session_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: exclude_source_session)
    update_report_template_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: exclude_source_session)
    update_report_template_sections_scoped(session, old_pattern, new_pattern, exclude_source_session: exclude_source_session)
    update_sms_plan_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: exclude_source_session)
    update_question_feedback_spectrum_scoped(session, old_pattern, new_pattern, exclude_source_session: exclude_source_session)
  end

  def source_session_modes
    @include_source_session ? [true, false] : [true]
  end

  def days_after_date_scope
    Session.where(intervention_id: session.intervention_id)
  end

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
