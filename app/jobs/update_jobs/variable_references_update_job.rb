# frozen_string_literal: true

class UpdateJobs::VariableReferencesUpdateJob < CloneJob
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on ActiveRecord::LockWaitTimeout, wait: 5.seconds, attempts: 3

  private

  def with_formula_update_lock(intervention_id)
    intervention = Intervention.find(intervention_id)

    return if intervention.formula_update_in_progress?

    intervention.update!(formula_update_in_progress: true)

    begin
      yield intervention
    rescue StandardError => e
      Rails.logger.error "[#{self.class.name}] Failed to update formula references: #{e.message}"
      Rails.logger.error "[#{self.class.name}] Backtrace: #{e.backtrace.join("\n")}"
      raise
    ensure
      intervention.update!(formula_update_in_progress: false)
    end
  end

  def update_chart_formulas(intervention_id, old_var, new_var)
    intervention = Intervention.find(intervention_id)
    organization = intervention.organization

    return if organization.nil? || organization.reporting_dashboard.nil?

    base_query = organization.charts.joins(:dashboard_section)

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

  def build_jsonb_formula_update_sql(table_name, old_var, new_var, base_query)
    escaped_new = ActiveRecord::Base.connection.quote(new_var)
    regex_pattern = ActiveRecord::Base.connection.quote("\\m#{Regexp.escape(old_var)}\\M")

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
    regex_pattern = ActiveRecord::Base.connection.quote("\\m#{Regexp.escape(old_var)}\\M")

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
    SQL
  end

  def build_jsonb_single_formula_update_sql(table_name, old_var, new_var, base_query)
    escaped_new = ActiveRecord::Base.connection.quote(new_var)
    regex_pattern = ActiveRecord::Base.connection.quote("\\m#{Regexp.escape(old_var)}\\M")

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
    regex_pattern = ActiveRecord::Base.connection.quote("\\m#{Regexp.escape(old_var)}\\M")

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
    @question_base_query ||= {}
    key = [session.id, exclude_source_session]
    @question_base_query[key] ||= if exclude_source_session
                                    Question.joins(question_group: { session: :intervention })
                                            .where(interventions: { id: session.intervention_id })
                                            .where.not(question_groups: { session_id: session.id })
                                  else
                                    Question.joins(:question_group)
                                            .where(question_groups: { session_id: session.id })
                                  end
  end

  def build_question_group_base_query(session, exclude_source_session)
    @question_group_base_query ||= {}
    key = [session.id, exclude_source_session]
    @question_group_base_query[key] ||= if exclude_source_session
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
    @session_base_query ||= {}
    key = [session.id, exclude_source_session]
    @session_base_query[key] ||= if exclude_source_session
                                   Session.where(intervention_id: session.intervention_id)
                                          .where.not(id: session.id)
                                 else
                                   Session.where(id: session.id)
                                 end
  end

  def build_report_template_section_base_query(session, exclude_source_session)
    @report_template_section_base_query ||= {}
    key = [session.id, exclude_source_session]
    @report_template_section_base_query[key] ||= if exclude_source_session
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
