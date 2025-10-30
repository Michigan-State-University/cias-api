# frozen_string_literal: true

class V1::VariableReferences::AnswerOptionsService < V1::VariableReferences::BaseService
  def initialize(question_id, changed_answer_values)
    super()
    @question_id = question_id
    @changed_answer_values = changed_answer_values
  end

  def call
    return if @changed_answer_values.blank?

    ActiveRecord::Base.transaction do
      update_question_narrator_reflection_answer_options_scoped(source_session, false)
      update_question_narrator_reflection_answer_options_scoped(source_session, true)
    end
  end

  private

  def question
    @question ||= Question.find(@question_id)
  end

  def source_session
    @source_session ||= question.session
  end

  def update_question_narrator_reflection_answer_options_scoped(session, exclude_source_session)
    base_query = build_question_base_query(session, exclude_source_session)
    update_sql = build_narrator_reflection_answer_options_update_sql('questions', base_query)

    ActiveRecord::Base.connection.execute(update_sql)
  end

  def build_narrator_reflection_answer_options_update_sql(table_name, base_query)
    narrator_column = "#{table_name}.narrator"

    normalized_changes = @changed_answer_values.transform_values do |value_map|
      value_map.transform_keys { |k| normalize_payload(k) }
              .transform_values { |v| normalize_payload(v) }
    end

    case_statements = normalized_changes.flat_map do |variable, value_map|
      value_map.map do |old_value, new_value|
        escaped_old = ActiveRecord::Base.connection.quote(old_value)
        escaped_new = ActiveRecord::Base.connection.quote(new_value)
        json_new_value = ActiveRecord::Base.connection.quote(new_value.to_json)

        escaped_old_like = ActiveRecord::Base.connection.quote("#{old_value} - %")
        new_grid_payload_sql = "to_jsonb(#{escaped_new} || ' - ' || split_part(reflection_item->>'payload', ' - ', 2))"

        <<~CASE.squish
          WHEN reflection_item->>'variable' = #{ActiveRecord::Base.connection.quote(variable)} AND reflection_item->>'payload' = #{escaped_old}
          THEN jsonb_set(reflection_item, '{payload}', #{json_new_value}::jsonb)

          WHEN reflection_item->>'variable' = #{ActiveRecord::Base.connection.quote(variable)} AND reflection_item->>'payload' LIKE #{escaped_old_like}
          THEN jsonb_set(reflection_item, '{payload}', #{new_grid_payload_sql})
        CASE
      end
    end.join(' ')

    id_subquery = base_query.select("#{table_name}.id")
                            .where("#{narrator_column}::text LIKE ?", '%Reflection%')
                            .reorder('')
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
