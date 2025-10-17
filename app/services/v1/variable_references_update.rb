# frozen_string_literal: true

class V1::VariableReferencesUpdate
  def self.call(intervention_id, &block)
    new(intervention_id).call(&block)
  end

  def self.update_question_variable_references(question_id, old_variable_name, new_variable_name)
    return if old_variable_name == new_variable_name
    return if old_variable_name.blank? || new_variable_name.blank?

    question = Question.find(question_id)
    return if question.question_variables.include?(new_variable_name)

    session = question.session

    call(session.intervention_id) do |service|
      service.update_question_variable_direct_references(session, old_variable_name, new_variable_name)
      service.update_question_variable_cross_session_references(session, old_variable_name, new_variable_name)
      Rails.logger.info "[V1::VariableReferencesUpdate] Question variable references updated: #{old_variable_name} -> #{new_variable_name}"
    end
  end

  def self.update_session_variable_references(session_id, old_session_variable, new_session_variable)
    return if old_session_variable == new_session_variable
    return if old_session_variable.blank? || new_session_variable.blank?

    session = Session.find(session_id)

    call(session.intervention_id) do |service|
      patterns_to_update = [old_session_variable] + extract_question_variables_from_session(session).map { |var| "#{old_session_variable}.#{var}" }
      new_patterns = [new_session_variable] + extract_question_variables_from_session(session).map { |var| "#{new_session_variable}.#{var}" }

      patterns_to_update.zip(new_patterns).each do |old_pattern, new_pattern|
        service.update_session_variable_cross_session_references(session, old_pattern, new_pattern)
      end
      Rails.logger.info "[V1::VariableReferencesUpdate] Session variable references updated: #{old_session_variable} -> #{new_session_variable}"
    end
  end

  def self.extract_question_variables_from_session(session)
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

  def initialize(intervention_id)
    @intervention_id = intervention_id
    @intervention = nil
    @question_base_queries = {}
    @question_group_base_queries = {}
    @session_base_queries = {}
    @report_template_section_base_queries = {}
  end

  def call
    with_formula_update_lock do
      ActiveRecord::Base.transaction do
        yield self
      end
    end
  end

  def update_chart_formulas(old_var, new_var)
    organization = intervention.organization

    return if organization.nil? || organization.reporting_dashboard.nil?

    base_query = organization.charts.joins(:dashboard_section)

    update_sql = build_jsonb_single_formula_update_sql('charts', old_var, new_var, base_query)
    execute_update(update_sql)
  end

  def update_question_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    base_query = build_question_base_query(session, exclude_source_session)
    update_sql = build_jsonb_formula_update_sql('questions', old_var, new_var, base_query)
    execute_update(update_sql)
  end

  def update_question_narrator_reflection_variables_scoped(session, old_var, new_var, exclude_source_session: false)
    base_query = build_question_base_query(session, exclude_source_session)
    update_sql = build_narrator_reflection_variables_update_sql('questions', old_var, new_var, base_query)
    execute_update(update_sql)
  end

  def update_question_narrator_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    base_query = build_question_base_query(session, exclude_source_session)
    update_sql = build_narrator_blocks_formula_update_sql('questions', old_var, new_var, base_query)
    execute_update(update_sql)
  end

  def update_question_group_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    base_query = build_question_group_base_query(session, exclude_source_session)
    update_sql = build_jsonb_formula_update_sql('question_groups', old_var, new_var, base_query)
    execute_update(update_sql)
  end

  def update_session_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    base_query = build_session_base_query(session, exclude_source_session)
    update_sql = build_jsonb_formula_update_sql('sessions', old_var, new_var, base_query)
    execute_update(update_sql)
  end

  def update_report_template_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    base_query = build_report_template_section_base_query(session, exclude_source_session)
    update_sql = build_text_formula_update_sql('report_template_sections', 'formula', old_var, new_var, base_query)
    execute_update(update_sql)
  end

  def update_question_variable_direct_references(session, old_var, new_var)
    update_question_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    update_question_narrator_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    update_question_narrator_reflection_variables_scoped(session, old_var, new_var, exclude_source_session: false)
    update_question_group_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    update_session_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
    update_report_template_formulas_scoped(session, old_var, new_var, exclude_source_session: false)
  end

  def update_question_variable_cross_session_references(session, old_var, new_var)
    old_cross_session_pattern = "#{session.variable}.#{old_var}"
    new_cross_session_pattern = "#{session.variable}.#{new_var}"

    update_question_formulas_scoped(session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
    update_question_narrator_formulas_scoped(session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
    update_question_narrator_reflection_variables_scoped(session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
    update_question_group_formulas_scoped(session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
    update_session_formulas_scoped(session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
    update_report_template_formulas_scoped(session, old_cross_session_pattern, new_cross_session_pattern, exclude_source_session: true)
    update_chart_formulas(session.intervention_id, old_cross_session_pattern, new_cross_session_pattern)
  end

  def update_session_variable_cross_session_references(session, old_pattern, new_pattern)
    update_question_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: true)
    update_question_narrator_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: true)
    update_session_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: true)
    update_question_group_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: true)
    update_report_template_formulas_scoped(session, old_pattern, new_pattern, exclude_source_session: true)
    update_chart_formulas(session.intervention_id, old_pattern, new_pattern)
  end

  private

  # Memoized intervention instance to avoid repeated database queries
  def intervention
    @intervention ||= Intervention.find(@intervention_id)
  end

  # Execute SQL update with error handling
  def execute_update(sql)
    return if sql.blank?

    ActiveRecord::Base.connection.execute(sql)
  rescue ActiveRecord::StatementInvalid => e
    Rails.logger.error "[V1::VariableReferencesUpdate] SQL execution failed: #{e.message}"
    raise
  end

  # Acquire lock on intervention to prevent concurrent formula updates
  def with_formula_update_lock
    return if intervention.formula_update_in_progress?

    intervention.update!(formula_update_in_progress: true)

    begin
      yield
    rescue StandardError => e
      Rails.logger.error "[V1::VariableReferencesUpdate] Failed to update formula references: #{e.message}"
      Rails.logger.error "[V1::VariableReferencesUpdate] Backtrace:\n#{e.backtrace.join("\n")}"
      raise
    ensure
      # Reload to get fresh state before updating
      intervention.reload.update!(formula_update_in_progress: false)
    end
  end

  def build_jsonb_formula_update_sql(table_name, old_var, new_var, base_query)
    escaped_new = ActiveRecord::Base.connection.quote(new_var)
    # Use \y for word boundaries in PostgreSQL (more reliable than \m)
    regex_pattern = ActiveRecord::Base.connection.quote("\\y#{Regexp.escape(old_var)}\\y")

    formulas_column = "#{table_name}.formulas"

    id_subquery = base_query.select("#{table_name}.id")
                            .where("#{formulas_column}::text LIKE ?", "%#{sanitize_like_pattern(old_var)}%")
                            .to_sql

    <<~SQL.squish
      UPDATE #{table_name}
      SET formulas = (
        SELECT jsonb_agg(
          CASE
            WHEN formula_item ? 'payload' AND formula_item->>'payload' ~ #{regex_pattern}
            THEN jsonb_set(
              formula_item,
              '{payload}',
              to_jsonb(regexp_replace(formula_item->>'payload', #{regex_pattern}, #{escaped_new}, 'g'))
            )
            ELSE formula_item
          END
        )
        FROM jsonb_array_elements(#{table_name}.formulas) AS formula_item
      ),
      updated_at = NOW()
      WHERE #{table_name}.id IN (
        #{id_subquery}
      )
      AND #{table_name}.formulas IS NOT NULL
      AND jsonb_typeof(#{table_name}.formulas) = 'array'
    SQL
  end

  def build_text_formula_update_sql(table_name, column_name, old_var, new_var, base_query)
    escaped_new = ActiveRecord::Base.connection.quote(new_var)
    # Use \y for word boundaries in PostgreSQL (more reliable than \m)
    regex_pattern = ActiveRecord::Base.connection.quote("\\y#{Regexp.escape(old_var)}\\y")

    full_column_name = "#{table_name}.#{column_name}"

    id_subquery = base_query.select("#{table_name}.id")
                            .where("#{full_column_name} LIKE ?", "%#{sanitize_like_pattern(old_var)}%")
                            .to_sql

    <<~SQL.squish
      UPDATE #{table_name}
      SET #{column_name} = regexp_replace(#{table_name}.#{column_name}, #{regex_pattern}, #{escaped_new}, 'g'),
          updated_at = NOW()
      WHERE #{table_name}.id IN (
        #{id_subquery}
      )
      AND #{table_name}.#{column_name} IS NOT NULL
    SQL
  end

  def build_jsonb_single_formula_update_sql(table_name, old_var, new_var, base_query)
    escaped_new = ActiveRecord::Base.connection.quote(new_var)
    # Use \y for word boundaries in PostgreSQL (more reliable than \m)
    regex_pattern = ActiveRecord::Base.connection.quote("\\y#{Regexp.escape(old_var)}\\y")

    formula_column = "#{table_name}.formula"

    id_subquery = base_query.select("#{table_name}.id")
                            .where("#{formula_column}::text LIKE ?", "%#{sanitize_like_pattern(old_var)}%")
                            .to_sql

    <<~SQL.squish
      UPDATE #{table_name}
      SET formula = (
        CASE
          WHEN #{formula_column} ? 'payload' AND #{formula_column}->>'payload' ~ #{regex_pattern}
          THEN jsonb_set(
            #{formula_column},
            '{payload}',
            to_jsonb(regexp_replace(#{formula_column}->>'payload', #{regex_pattern}, #{escaped_new}, 'g'))
          )
          ELSE #{formula_column}
        END
      ),
      updated_at = NOW()
      WHERE #{table_name}.id IN (
        #{id_subquery}
      )
      AND #{table_name}.formula IS NOT NULL
      AND jsonb_typeof(#{table_name}.formula) = 'object'
    SQL
  end

  def build_narrator_blocks_formula_update_sql(table_name, old_var, new_var, base_query)
    escaped_new = ActiveRecord::Base.connection.quote(new_var)
    # Use \y for word boundaries in PostgreSQL (more reliable than \m)
    regex_pattern = ActiveRecord::Base.connection.quote("\\y#{Regexp.escape(old_var)}\\y")

    narrator_column = "#{table_name}.narrator"

    id_subquery = base_query.select("#{table_name}.id")
                            .where("#{narrator_column}::text LIKE ?", "%#{sanitize_like_pattern(old_var)}%")
                            .reorder("")
                            .to_sql

    <<~SQL.squish
      UPDATE #{table_name}
      SET narrator = jsonb_set(
        narrator,
        '{blocks}',
        (
          SELECT COALESCE(jsonb_agg(
            CASE
              WHEN block_item ? 'payload' AND block_item->>'payload' ~ #{regex_pattern}
              THEN jsonb_set(
                block_item,
                '{payload}',
                to_jsonb(regexp_replace(block_item->>'payload', #{regex_pattern}, #{escaped_new}, 'g'))
              )
              ELSE block_item
            END
          ), '[]'::jsonb)
          FROM jsonb_array_elements(COALESCE(#{narrator_column}->'blocks', '[]'::jsonb)) AS block_item
        )
      ),
      updated_at = NOW()
      WHERE #{table_name}.id IN (
        #{id_subquery}
      )
      AND #{narrator_column} IS NOT NULL
      AND jsonb_typeof(COALESCE(#{narrator_column}->'blocks', '[]'::jsonb)) = 'array'
    SQL
  end

  def build_narrator_reflection_variables_update_sql(table_name, old_var, new_var, base_query)
    escaped_old = ActiveRecord::Base.connection.quote(old_var)
    json_new_var = ActiveRecord::Base.connection.quote("\"#{new_var}\"")

    narrator_column = "#{table_name}.narrator"

    id_subquery = base_query.select("#{table_name}.id")
                            .where("#{narrator_column}::text LIKE ?", "%#{sanitize_like_pattern(old_var)}%")
                            .reorder("")
                            .to_sql

    <<~SQL.squish
      UPDATE #{table_name}
      SET narrator = jsonb_set(
        narrator,
        '{blocks}',
        (
          SELECT COALESCE(jsonb_agg(
            CASE
              WHEN block_item->>'type' = 'Reflection' AND block_item ? 'reflections'
              THEN jsonb_set(
                block_item,
                '{reflections}',
                (
                  SELECT COALESCE(jsonb_agg(
                    CASE
                      WHEN reflection_item ? 'variable' AND reflection_item->>'variable' = #{escaped_old}
                      THEN jsonb_set(reflection_item, '{variable}', #{json_new_var}::jsonb)
                      ELSE reflection_item
                    END
                  ), '[]'::jsonb)
                  FROM jsonb_array_elements(block_item->'reflections') AS reflection_item
                )
              )
              ELSE block_item
            END
          ), '[]'::jsonb)
          FROM jsonb_array_elements(COALESCE(#{narrator_column}->'blocks', '[]'::jsonb)) AS block_item
        )
      ),
      updated_at = NOW()
      WHERE #{table_name}.id IN (
        #{id_subquery}
      )
      AND #{narrator_column} IS NOT NULL
      AND jsonb_typeof(COALESCE(#{narrator_column}->'blocks', '[]'::jsonb)) = 'array'
    SQL
  end

  def build_question_base_query(session, exclude_source_session)
    cache_key = [session.id, exclude_source_session]

    @question_base_queries[cache_key] ||= if exclude_source_session
                                             Question.joins(question_group: { session: :intervention })
                                                     .where(interventions: { id: session.intervention_id })
                                                     .where.not(question_groups: { session_id: session.id })
                                           else
                                             Question.joins(:question_group)
                                                     .where(question_groups: { session_id: session.id })
                                           end
  end

  def build_question_group_base_query(session, exclude_source_session)
    cache_key = [session.id, exclude_source_session]

    @question_group_base_queries[cache_key] ||= if exclude_source_session
                                                   QuestionGroup.joins(session: :intervention)
                                                               .where(interventions: { id: session.intervention_id })
                                                               .where.not(session_id: session.id)
                                                               .where.not(formulas: nil)
                                                 else
                                                   QuestionGroup.where(session_id: session.id)
                                                               .where.not(formulas: nil)
                                                 end
  end

  def build_session_base_query(session, exclude_source_session)
    cache_key = [session.id, exclude_source_session]

    @session_base_queries[cache_key] ||= if exclude_source_session
                                            Session.where(intervention_id: session.intervention_id)
                                                   .where.not(id: session.id)
                                          else
                                            Session.where(id: session.id)
                                          end
  end

  def build_report_template_section_base_query(session, exclude_source_session)
    cache_key = [session.id, exclude_source_session]

    @report_template_section_base_queries[cache_key] ||= if exclude_source_session
                                                            ReportTemplate::Section.joins(report_template: { session: :intervention })
                                                                                  .where(interventions: { id: session.intervention_id })
                                                                                  .where.not(sessions: { id: session.id })
                                                          else
                                                            ReportTemplate::Section.joins(report_template: :session)
                                                                                  .where(sessions: { id: session.id })
                                                          end
  end

  def sanitize_like_pattern(pattern)
    pattern.gsub(/[%_\\]/) { |char| "\\#{char}" }
  end
end