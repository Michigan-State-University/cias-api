# frozen_string_literal: true

class V1::VariableReferences::BaseService
  include V1::VariableReferences::SqlBuilder
  include V1::VariableReferences::QueryBuilder

  def self.call(...)
    new(...).call
  end

  private

  def update_chart_formulas(intervention_id, old_var, new_var)
    intervention = Intervention.find(intervention_id)
    organization = intervention.organization

    return if organization.nil? || organization.reporting_dashboard.nil?

    base_query = organization.charts.joins(:dashboard_section)

    return if base_query.empty?

    update_sql = build_jsonb_single_formula_update_sql('charts', old_var, new_var, base_query)
    ActiveRecord::Base.connection.execute(update_sql)
  end

  def update_question_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    base_query = build_question_base_query(session, exclude_source_session)
    update_sql = build_jsonb_formula_update_sql('questions', old_var, new_var, base_query)
    ActiveRecord::Base.connection.execute(update_sql)
  end

  def update_question_narrator_reflection_variables_scoped(session, old_var, new_var, exclude_source_session: false)
    base_query = build_question_base_query(session, exclude_source_session)
    update_sql = build_narrator_reflection_variables_update_sql('questions', old_var, new_var, base_query)
    ActiveRecord::Base.connection.execute(update_sql)
  end

  def update_question_narrator_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    base_query = build_question_base_query(session, exclude_source_session)
    update_sql = build_narrator_blocks_formula_update_sql('questions', old_var, new_var, base_query)
    ActiveRecord::Base.connection.execute(update_sql)
  end

  def update_question_group_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    base_query = build_question_group_base_query(session, exclude_source_session)
    update_sql = build_jsonb_formula_update_sql('question_groups', old_var, new_var, base_query)
    ActiveRecord::Base.connection.execute(update_sql)
  end

  def update_session_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    base_query = build_session_base_query(session, exclude_source_session)
    update_sql = build_jsonb_formula_update_sql('sessions', old_var, new_var, base_query)
    ActiveRecord::Base.connection.execute(update_sql)
  end

  def update_report_template_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    base_query = build_report_template_section_base_query(session, exclude_source_session)
    update_sql = build_text_formula_update_sql('report_template_sections', 'formula', old_var, new_var, base_query)
    ActiveRecord::Base.connection.execute(update_sql)
  end

  def update_days_after_date_variable_references(old_var, new_var)
    update_sql = <<-SQL.squish
      UPDATE sessions
      SET days_after_date_variable_name = #{ActiveRecord::Base.connection.quote(new_var)}
      WHERE days_after_date_variable_name = #{ActiveRecord::Base.connection.quote(old_var)}
    SQL
    ActiveRecord::Base.connection.execute(update_sql)
  end

  def update_sms_plan_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    base_query = build_sms_plan_base_query(session, exclude_source_session)

    update_formula_sql = build_text_formula_update_sql('sms_plans', 'formula', old_var, new_var, base_query)
    ActiveRecord::Base.connection.execute(update_formula_sql)

    update_no_formula_sql = build_text_formula_update_sql('sms_plans', 'no_formula_text', old_var, new_var, base_query)
    ActiveRecord::Base.connection.execute(update_no_formula_sql)
  end
end
