# frozen_string_literal: true

class V1::VariableReferences::AnswerValuesService < V1::VariableReferences::BaseService
  def initialize(question_id, changed_answer_values)
    super()
    @question_id = question_id
    @changed_answer_values = changed_answer_values
  end

  def call
    return if @changed_answer_values.blank?

    Rails.logger.info "[#{self.class.name}] Starting update for question_id: #{@question_id}, changes: #{@changed_answer_values.inspect}"
    Rails.logger.info "[#{self.class.name}] Question narrator: #{question.narrator.inspect}"

    ActiveRecord::Base.transaction do
      update_question_narrator_reflection_values_scoped(source_session, false)
      update_question_narrator_reflection_values_scoped(source_session, true)
    end

    Rails.logger.info "[#{self.class.name}] Successfully completed update for question_id: #{@question_id}"
  end

  private

  def question
    @question ||= Question.find(@question_id)
  end

  def source_session
    @source_session ||= question.session
  end

  def update_question_narrator_reflection_values_scoped(session, exclude_source_session)
    base_query = build_question_base_query(session, exclude_source_session)
    update_sql = build_narrator_reflection_values_update_sql('questions', base_query)

    Rails.logger.info "[#{self.class.name}] Executing SQL for session #{session.id}, exclude_source: #{exclude_source_session}"
    Rails.logger.info "[#{self.class.name}] SQL: #{update_sql}"

    result = ActiveRecord::Base.connection.execute(update_sql)
    affected_rows = result.cmd_tuples

    Rails.logger.info "[#{self.class.name}] SQL execution completed, affected rows: #{affected_rows}"
  end

  def build_narrator_reflection_values_update_sql(table_name, base_query)
    narrator_column = "#{table_name}.narrator"

    Rails.logger.info "[#{self.class.name}] Building SQL for table: #{table_name}, changes: #{@changed_answer_values.inspect}"

    # Normalize payloads: strip surrounding <p> tags since reflections store plain text
    normalized_changes = @changed_answer_values.transform_values do |value_map|
      value_map.transform_keys { |k| normalize_payload(k) }
              .transform_values { |v| normalize_payload(v) }
    end

    Rails.logger.info "[#{self.class.name}] Normalized changes: #{normalized_changes.inspect}"

    # Build CASE statements for each changed value
    case_statements = normalized_changes.flat_map do |variable, value_map|
      Rails.logger.info "[#{self.class.name}] Processing variable: #{variable}, value changes: #{value_map.inspect}"

      value_map.map do |old_value, new_value|
        escaped_old = ActiveRecord::Base.connection.quote(old_value)
        json_new_value = ActiveRecord::Base.connection.quote(new_value.to_json)
        Rails.logger.info "[#{self.class.name}] Old value: #{old_value.inspect} -> New value: #{new_value.inspect}"

        <<~CASE.squish
          WHEN reflection_item->>'variable' = #{ActiveRecord::Base.connection.quote(variable)} AND reflection_item->>'payload' = #{escaped_old}
          THEN jsonb_set(reflection_item, '{payload}', #{json_new_value}::jsonb)
        CASE
      end
    end.join(' ')

    id_subquery = base_query.select("#{table_name}.id")
                            .where("#{narrator_column}::text LIKE ?", '%Reflection%')
                            .reorder('')
                            .to_sql

    question_count = base_query.where("#{narrator_column}::text LIKE ?", '%Reflection%').count
    Rails.logger.info "[#{self.class.name}] Found #{question_count} questions with reflections to update"

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
                      #{case_statements}
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

  def normalize_payload(payload)
    return payload unless payload.is_a?(String)

    # Strip surrounding <p> tags and whitespace to match reflection format
    payload.strip.gsub(%r{\A<p>|</p>\z}, '').strip
  end
end
