# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module V1::VariableReferences::AnswerOptions::SqlBuilder
  private

  def build_update_reflection_payloads_sql(base_query)
    return nil if changed_answer_values.blank?

    normalized_changes = normalize_answer_changes(changed_answer_values)

    # Build CASE statements for payload updates
    case_statements = build_payload_update_cases(normalized_changes)

    # Find questions with Reflection blocks that reference this question_id
    id_subquery = base_query.select('questions.id')
                            .where("questions.narrator->>'blocks' LIKE ?", "%#{question_id}%")
                            .where("questions.narrator->>'blocks' LIKE ?", '%Reflection%')
                            .reorder('')
                            .to_sql

    <<~SQL.squish
      UPDATE questions
      SET narrator = jsonb_set(
        narrator,
        '{blocks}',
        (
          SELECT COALESCE(jsonb_agg(
            CASE
              WHEN block_item->>'type' = 'Reflection'
                AND block_item->>'question_id' = #{ActiveRecord::Base.connection.quote(question_id)}
                AND block_item ? 'reflections'
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
          FROM jsonb_array_elements(COALESCE(questions.narrator->'blocks', '[]'::jsonb)) AS block_item
        )
      ),
      updated_at = NOW()
      WHERE questions.id IN (#{id_subquery})
      AND questions.narrator IS NOT NULL
      AND jsonb_typeof(COALESCE(questions.narrator->'blocks', '[]'::jsonb)) = 'array'
    SQL
  end

  def build_add_new_reflections_sql(base_query)
    return nil if new_answer_options.blank?

    new_reflections = build_new_reflection_objects
    return nil if new_reflections.empty?

    new_reflections_sql = new_reflections.map do |reflection|
      "#{ActiveRecord::Base.connection.quote(reflection.to_json)}::jsonb"
    end.join(', ')

    id_subquery = base_query.select('questions.id')
                            .where("questions.narrator->>'blocks' LIKE ?", "%#{question_id}%")
                            .where("questions.narrator->>'blocks' LIKE ?", '%Reflection%')
                            .reorder('')
                            .to_sql

    <<~SQL.squish
      UPDATE questions
      SET narrator = jsonb_set(
        narrator,
        '{blocks}',
        (
          SELECT COALESCE(jsonb_agg(
            CASE
              WHEN block_item->>'type' = 'Reflection'
                AND block_item->>'question_id' = #{ActiveRecord::Base.connection.quote(question_id)}
                AND block_item ? 'reflections'
              THEN jsonb_set(
                block_item,
                '{reflections}',
                COALESCE(block_item->'reflections', '[]'::jsonb) || jsonb_build_array(#{new_reflections_sql})
              )
              ELSE block_item
            END
          ), '[]'::jsonb)
          FROM jsonb_array_elements(COALESCE(questions.narrator->'blocks', '[]'::jsonb)) AS block_item
        )
      ),
      updated_at = NOW()
      WHERE questions.id IN (#{id_subquery})
      AND questions.narrator IS NOT NULL
      AND jsonb_typeof(COALESCE(questions.narrator->'blocks', '[]'::jsonb)) = 'array'
    SQL
  end

  def build_delete_reflections_sql(base_query)
    return nil if deleted_answer_options.blank?

    filter_conditions = build_deletion_filter_conditions

    id_subquery = base_query.select('questions.id')
                            .where("questions.narrator->>'blocks' LIKE ?", "%#{question_id}%")
                            .where("questions.narrator->>'blocks' LIKE ?", '%Reflection%')
                            .reorder('')
                            .to_sql

    <<~SQL.squish
      UPDATE questions
      SET narrator = jsonb_set(
        narrator,
        '{blocks}',
        (
          SELECT COALESCE(jsonb_agg(
            CASE
              WHEN block_item->>'type' = 'Reflection'
                AND block_item->>'question_id' = #{ActiveRecord::Base.connection.quote(question_id)}
                AND block_item ? 'reflections'
              THEN jsonb_set(
                block_item,
                '{reflections}',
                (
                  SELECT COALESCE(jsonb_agg(reflection_item), '[]'::jsonb)
                  FROM jsonb_array_elements(block_item->'reflections') AS reflection_item
                  WHERE NOT (#{filter_conditions})
                )
              )
              ELSE block_item
            END
          ), '[]'::jsonb)
          FROM jsonb_array_elements(COALESCE(questions.narrator->'blocks', '[]'::jsonb)) AS block_item
        )
      ),
      updated_at = NOW()
      WHERE questions.id IN (#{id_subquery})
      AND questions.narrator IS NOT NULL
      AND jsonb_typeof(COALESCE(questions.narrator->'blocks', '[]'::jsonb)) = 'array'
    SQL
  end

  def build_update_column_payloads_sql(base_query)
    return nil if changed_columns.blank?

    normalized_changes = normalize_column_changes(changed_columns)

    case_statements = build_column_update_cases(normalized_changes)

    id_subquery = base_query.select('questions.id')
                            .where("questions.narrator->>'blocks' LIKE ?", "%#{question_id}%")
                            .where("questions.narrator->>'blocks' LIKE ?", '%Reflection%')
                            .reorder('')
                            .to_sql

    <<~SQL.squish
      UPDATE questions
      SET narrator = jsonb_set(
        narrator,
        '{blocks}',
        (
          SELECT COALESCE(jsonb_agg(
            CASE
              WHEN block_item->>'type' = 'Reflection'
                AND block_item->>'question_id' = #{ActiveRecord::Base.connection.quote(question_id)}
                AND block_item ? 'reflections'
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
          FROM jsonb_array_elements(COALESCE(questions.narrator->'blocks', '[]'::jsonb)) AS block_item
        )
      ),
      updated_at = NOW()
      WHERE questions.id IN (#{id_subquery})
      AND questions.narrator IS NOT NULL
      AND jsonb_typeof(COALESCE(questions.narrator->'blocks', '[]'::jsonb)) = 'array'
    SQL
  end

  # Build SQL to add new reflections for new grid columns (one for each row × new column)
  def build_add_new_column_reflections_sql(base_query, rows)
    return nil if new_columns.blank? || rows.blank?

    new_reflections = []
    new_columns.pluck('value', 'payload').each do |column_value, column_payload|
      rows.each do |row|
        row_payload = normalize_payload(row['payload'])
        normalized_column = normalize_payload(column_payload)
        combined_payload = "#{row_payload} - #{normalized_column}"

        escaped_payload = ActiveRecord::Base.connection.quote(combined_payload)
        escaped_value = ActiveRecord::Base.connection.quote(column_value)

        new_reflections << "jsonb_build_object('payload', #{escaped_payload}, 'value', #{escaped_value})"
      end
    end

    new_reflections_sql = new_reflections.join(', ')

    id_subquery = base_query.select('questions.id')
                            .where("questions.narrator->>'blocks' LIKE ?", "%#{question_id}%")
                            .where("questions.narrator->>'blocks' LIKE ?", '%Reflection%')
                            .reorder('')
                            .to_sql

    <<~SQL.squish
      UPDATE questions
      SET narrator = jsonb_set(
        narrator,
        '{blocks}',
        (
          SELECT COALESCE(jsonb_agg(
            CASE
              WHEN block_item->>'type' = 'Reflection'
                AND block_item->>'question_id' = #{ActiveRecord::Base.connection.quote(question_id)}
                AND block_item ? 'reflections'
              THEN jsonb_set(
                block_item,
                '{reflections}',
                COALESCE(block_item->'reflections', '[]'::jsonb) || jsonb_build_array(#{new_reflections_sql})
              )
              ELSE block_item
            END
          ), '[]'::jsonb)
          FROM jsonb_array_elements(COALESCE(questions.narrator->'blocks', '[]'::jsonb)) AS block_item
        )
      ),
      updated_at = NOW()
      WHERE questions.id IN (#{id_subquery})
      AND questions.narrator IS NOT NULL
      AND jsonb_typeof(COALESCE(questions.narrator->'blocks', '[]'::jsonb)) = 'array'
    SQL
  end

  def build_delete_column_reflections_sql(base_query)
    return nil if deleted_columns.blank?

    filter_conditions = deleted_columns.map do |column_value, _column_payload|
      escaped_value = ActiveRecord::Base.connection.quote(column_value)
      "reflection_item->>'value' = #{escaped_value}"
    end.join(' OR ')

    id_subquery = base_query.select('questions.id')
                            .where("questions.narrator->>'blocks' LIKE ?", "%#{question_id}%")
                            .where("questions.narrator->>'blocks' LIKE ?", '%Reflection%')
                            .reorder('')
                            .to_sql

    <<~SQL.squish
      UPDATE questions
      SET narrator = jsonb_set(
        narrator,
        '{blocks}',
        (
          SELECT COALESCE(jsonb_agg(
            CASE
              WHEN block_item->>'type' = 'Reflection'
                AND block_item->>'question_id' = #{ActiveRecord::Base.connection.quote(question_id)}
                AND block_item ? 'reflections'
              THEN jsonb_set(
                block_item,
                '{reflections}',
                (
                  SELECT COALESCE(jsonb_agg(reflection_item), '[]'::jsonb)
                  FROM jsonb_array_elements(block_item->'reflections') AS reflection_item
                  WHERE NOT (#{filter_conditions})
                )
              )
              ELSE block_item
            END
          ), '[]'::jsonb)
          FROM jsonb_array_elements(COALESCE(questions.narrator->'blocks', '[]'::jsonb)) AS block_item
        )
      ),
      updated_at = NOW()
      WHERE questions.id IN (#{id_subquery})
      AND questions.narrator IS NOT NULL
      AND jsonb_typeof(COALESCE(questions.narrator->'blocks', '[]'::jsonb)) = 'array'
    SQL
  end
end
# rubocop:enable Metrics/ModuleLength
