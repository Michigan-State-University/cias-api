# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module V1::VariableReferences::SqlBuilder
  private

  # A question variable is a legal standalone token ("mood > 3", `.:mood:.`), so it is matched bare.
  # SessionService overrides both hooks — a session variable never appears standalone.
  def variable_regex(old_var)
    "\\m#{Regexp.escape(old_var)}\\M"
  end

  def variable_replacement(new_var)
    escape_regexp_replacement(new_var)
  end

  # regexp_replace's replacement has its own mini-language (\1..\9, \&, \\). A variable is free
  # text, so neutralise backslashes before they reach it.
  def escape_regexp_replacement(value)
    value.gsub('\\') { '\\\\' }
  end

  def build_jsonb_formula_update_sql(table_name, old_var, new_var, base_query)
    escaped_new = ActiveRecord::Base.connection.quote(variable_replacement(new_var))
    regex_pattern = ActiveRecord::Base.connection.quote(variable_regex(old_var))

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
    escaped_new = ActiveRecord::Base.connection.quote(variable_replacement(new_var))
    regex_pattern = ActiveRecord::Base.connection.quote(variable_regex(old_var))

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
    escaped_new = ActiveRecord::Base.connection.quote(variable_replacement(new_var))
    regex_pattern = ActiveRecord::Base.connection.quote(variable_regex(old_var))

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
    escaped_new = ActiveRecord::Base.connection.quote(variable_replacement(new_var))
    regex_pattern = ActiveRecord::Base.connection.quote(variable_regex(old_var))

    narrator_column = "#{table_name}.narrator"

    id_subquery = base_query.select("#{table_name}.id")
                            .where("#{narrator_column}::text LIKE ?", "%#{sanitize_like_pattern(old_var)}%")
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

  def build_variant_content_update_sql(table_name, old_var, new_var, base_query)
    escaped_new = ActiveRecord::Base.connection.quote(variable_replacement(new_var))
    regex_pattern = ActiveRecord::Base.connection.quote(variable_regex(old_var))

    content_column = "#{table_name}.content"

    id_subquery = base_query.select("#{table_name}.id")
                            .where("#{content_column} LIKE ?", "%#{sanitize_like_pattern(old_var)}%")
                            .to_sql

    <<~SQL.squish
      UPDATE #{table_name}
      SET content = regexp_replace(#{table_name}.content, #{regex_pattern}, #{escaped_new}, 'g'),
          updated_at = NOW()
      WHERE #{table_name}.id IN (
        #{id_subquery}
      )
    SQL
  end

  # Question::Feedback keeps its formula in body->'data'->N->'spectrum'->'payload', not in `formulas`.
  # WITH ORDINALITY + ORDER BY because jsonb_agg may reorder and #apply_formula reads body_data[0].
  def build_feedback_spectrum_update_sql(table_name, old_var, new_var, base_query)
    escaped_new = ActiveRecord::Base.connection.quote(variable_replacement(new_var))
    regex_pattern = ActiveRecord::Base.connection.quote(variable_regex(old_var))

    body_column = "#{table_name}.body"

    id_subquery = base_query.select("#{table_name}.id")
                            .where("#{body_column}::text LIKE ?", "%#{sanitize_like_pattern(old_var)}%")
                            .reorder('')
                            .to_sql

    <<~SQL.squish
      UPDATE #{table_name}
      SET body = jsonb_set(
        body,
        '{data}',
        (
          SELECT COALESCE(jsonb_agg(
            CASE
              WHEN data_item->'spectrum' ? 'payload' AND data_item->'spectrum'->>'payload' ~ #{regex_pattern}
              THEN jsonb_set(
                data_item,
                '{spectrum,payload}',
                to_jsonb(regexp_replace(data_item->'spectrum'->>'payload', #{regex_pattern}, #{escaped_new}, 'g'))
              )
              ELSE data_item
            END
            ORDER BY data_ordinality
          ), '[]'::jsonb)
          FROM jsonb_array_elements(COALESCE(#{body_column}->'data', '[]'::jsonb))
               WITH ORDINALITY AS feedback_data(data_item, data_ordinality)
        )
      ),
      updated_at = NOW()
      WHERE #{table_name}.id IN (
        #{id_subquery}
      )
      AND #{body_column} IS NOT NULL
      AND jsonb_typeof(#{body_column}) = 'object'
      AND jsonb_typeof(#{body_column}->'data') = 'array'
    SQL
  end

  def sanitize_like_pattern(pattern)
    pattern.gsub(/[%_\\]/) { |char| "\\#{char}" }
  end
end
# rubocop:enable Metrics/ModuleLength
