# frozen_string_literal: true

# rubocop:disable Metrics/ModuleLength
module V1::VariableReferences::AnswerOptions::PayloadNormalizer
  private

  # Helper: Normalize answer changes by stripping HTML tags
  def normalize_answer_changes(changes)
    return [] if changes.blank?

    changes.map do |change|
      {
        'variable' => change['variable'],
        'new_variable' => change['new_variable'],
        'old_payload' => normalize_payload(change['old_payload']),
        'new_payload' => normalize_payload(change['new_payload']),
        'value' => change['value'],
        'new_value' => change['new_value']
      }.compact
    end
  end

  def build_payload_update_cases(normalized_changes)
    return '' if normalized_changes.blank?

    if question.type == 'Question::Single'
      build_single_question_update_cases(normalized_changes)
    else
      # Multiple or Grid questions
      build_variable_based_question_update_cases(normalized_changes)
    end.join(' ')
  end

  # Build CASE statements for Single questions
  # 1. If value is present: match by value (primary) with payload as disambiguation
  # 2. If value is not present: match by payload only
  def build_single_question_update_cases(changes_array)
    changes_array.map do |change|
      old_payload = change['old_payload']
      new_payload = change['new_payload']
      answer_value = change['value']
      new_value = change['new_value']

      escaped_old = ActiveRecord::Base.connection.quote(old_payload)
      json_new_payload = ActiveRecord::Base.connection.quote(new_payload.to_json)

      # Build WHERE conditions
      if answer_value.present?
        escaped_value = ActiveRecord::Base.connection.quote(answer_value)
        # Primary: Match by value (catches most cases)
        # Secondary: Match by value AND payload (for disambiguation when duplicate values might exist)
        value_match = "reflection_item->>'value' = #{escaped_value}"
        value_and_payload_match = "#{value_match} AND reflection_item->>'payload' = #{escaped_old}"
      else
        # No value: match by payload only
        value_match = nil
        value_and_payload_match = "reflection_item->>'payload' = #{escaped_old}"
      end

      # If value changed, update both payload and value fields
      if new_value.present? && new_value != answer_value
        escaped_new_value = ActiveRecord::Base.connection.quote(new_value.to_json)

        # Match by old value AND old payload for safety, update both fields
        <<~CASE.squish
          WHEN #{value_and_payload_match}
          THEN jsonb_set(
            jsonb_set(reflection_item, '{payload}', #{json_new_payload}::jsonb),
            '{value}',
            #{escaped_new_value}::jsonb
          )
        CASE
      elsif value_match
        # Only payload changed - try value first, then value+payload as fallback
        <<~CASE.squish
          WHEN #{value_match}
          THEN jsonb_set(reflection_item, '{payload}', #{json_new_payload}::jsonb)
        CASE
      else
        # No value available, match by payload only
        <<~CASE.squish
          WHEN #{value_and_payload_match}
          THEN jsonb_set(reflection_item, '{payload}', #{json_new_payload}::jsonb)
        CASE
      end
    end
  end

  # Build CASE statements for Multiple/Grid questions
  # Multiple/Grid questions have variables, so matching uses variable as the primary identifier
  # Hierarchy: variable -> value (if present) -> payload
  def build_variable_based_question_update_cases(changes_array)
    changes_array.map do |change|
      variable = change['variable']
      old_payload = change['old_payload']
      new_payload = change['new_payload']
      new_variable = change['new_variable']
      new_value = change['new_value']
      answer_value = change['value']

      escaped_old = ActiveRecord::Base.connection.quote(old_payload)
      escaped_new = ActiveRecord::Base.connection.quote(new_payload)
      json_new_payload = ActiveRecord::Base.connection.quote(new_payload.to_json)

      # Handle both simple payloads and grid payloads (with " - " separator)
      escaped_old_like = ActiveRecord::Base.connection.quote("#{old_payload} - %")
      new_grid_payload_sql = "to_jsonb(#{escaped_new} || ' - ' || split_part(reflection_item->>'payload', ' - ', 2))"

      # Build the update expression based on what changed
      update_expr = if new_variable && new_value
                      # Update payload, variable, AND value
                      escaped_new_var = ActiveRecord::Base.connection.quote(new_variable.to_json)
                      escaped_new_val = ActiveRecord::Base.connection.quote(new_value.to_json)
                      # Build nested jsonb_set calls
                      step1 = "jsonb_set(reflection_item, '{payload}', #{json_new_payload}::jsonb)"
                      step2 = "jsonb_set(#{step1}, '{variable}', #{escaped_new_var}::jsonb)"
                      "jsonb_set(#{step2}, '{value}', #{escaped_new_val}::jsonb)"
                    elsif new_variable
                      # Update payload AND variable
                      escaped_new_var = ActiveRecord::Base.connection.quote(new_variable.to_json)
                      step1 = "jsonb_set(reflection_item, '{payload}', #{json_new_payload}::jsonb)"
                      "jsonb_set(#{step1}, '{variable}', #{escaped_new_var}::jsonb)"
                    elsif new_value
                      # Update payload AND value
                      escaped_new_val = ActiveRecord::Base.connection.quote(new_value.to_json)
                      step1 = "jsonb_set(reflection_item, '{payload}', #{json_new_payload}::jsonb)"
                      "jsonb_set(#{step1}, '{value}', #{escaped_new_val}::jsonb)"
                    else
                      # Only update payload
                      "jsonb_set(reflection_item, '{payload}', #{json_new_payload}::jsonb)"
                    end

      # Build WHERE conditions - match by value if available for disambiguation
      if answer_value.present?
        escaped_value = ActiveRecord::Base.connection.quote(answer_value)
        payload_match = "reflection_item->>'value' = #{escaped_value} AND reflection_item->>'payload' = #{escaped_old}"
        grid_match = "reflection_item->>'value' = #{escaped_value} AND reflection_item->>'payload' LIKE #{escaped_old_like}"
      else
        payload_match = "reflection_item->>'payload' = #{escaped_old}"
        grid_match = "reflection_item->>'payload' LIKE #{escaped_old_like}"
      end

      if variable.nil?
        # No variable: match by payload (and value if available)
        <<~CASE.squish
          WHEN #{payload_match}
          THEN #{update_expr}

          WHEN #{grid_match}
          THEN jsonb_set(reflection_item, '{payload}', #{new_grid_payload_sql})
        CASE
      else
        # Variable exists: match by variable AND payload (and value if available)
        escaped_var = ActiveRecord::Base.connection.quote(variable)
        <<~CASE.squish
          WHEN (reflection_item->>'variable' = #{escaped_var} OR reflection_item->>'variable' IS NULL)
            AND #{payload_match}
          THEN #{update_expr}

          WHEN (reflection_item->>'variable' = #{escaped_var} OR reflection_item->>'variable' IS NULL)
            AND #{grid_match}
          THEN jsonb_set(reflection_item, '{payload}', #{new_grid_payload_sql})
        CASE
      end
    end
  end

  # Helper: Build new reflection objects for new answer options
  def build_new_reflection_objects
    # For Grid questions, new rows need to be combined with all columns
    return build_grid_row_reflection_objects if question.is_a?(Question::Grid)

    # For Single/Multiple questions, create simple reflections
    new_answer_options.map do |option|
      normalized_payload = normalize_payload(option['payload'])
      {
        variable: option['variable'],
        value: option['value'],
        payload: normalized_payload,
        text: [],
        sha256: [],
        audio_urls: []
      }
    end
  end

  # Build reflection objects for new grid rows (one for each row × column)
  def build_grid_row_reflection_objects
    return [] if new_answer_options.blank?

    columns = question.question_columns

    return [] if columns.blank?

    reflections = []
    new_answer_options.each do |row|
      row_payload = normalize_payload(row['payload'])

      columns.each do |col|
        col_payload = normalize_payload(col['payload'])
        combined_payload = "#{row_payload} - #{col_payload}"

        reflections << {
          variable: nil,
          value: col['value'],
          payload: combined_payload,
          text: [],
          sha256: [],
          audio_urls: []
        }
      end
    end

    reflections
  end

  # Helper: Normalize payload by stripping HTML tags
  def normalize_payload(payload)
    return payload unless payload.is_a?(String)

    normalized = payload.strip.gsub(%r{\A<p>|</p>\z}, '').strip
    normalized = '' if normalized.match?(%r{\A<br\s*/?>\z}i)
    normalized
  end

  # Helper: Build WHERE conditions to filter out deleted reflections
  # Uses value for matching when available (to handle duplicate payloads)
  # Hierarchy: value (if present) + payload > variable + payload > payload only
  def build_deletion_filter_conditions
    deleted_answer_options.map do |deletion|
      variable = deletion['variable']
      payload = normalize_payload(deletion['payload'])
      value = deletion['value']

      escaped_payload = ActiveRecord::Base.connection.quote(payload)
      # For Grid questions, also match payloads that start with "row - " (row deletions)
      escaped_payload_like = ActiveRecord::Base.connection.quote("#{payload} - %")

      if value.present?
        escaped_value = ActiveRecord::Base.connection.quote(value)
        value_exact = "(reflection_item->>'value' = #{escaped_value} AND reflection_item->>'payload' = #{escaped_payload})"
        value_grid = "(reflection_item->>'value' = #{escaped_value} AND reflection_item->>'payload' LIKE #{escaped_payload_like})"

        if variable.present?
          # Match by value+payload OR variable+value+payload
          escaped_var = ActiveRecord::Base.connection.quote(variable)
          var_value_exact = "(reflection_item->>'variable' = #{escaped_var} AND #{value_exact})"
          var_value_grid = "(reflection_item->>'variable' = #{escaped_var} AND #{value_grid})"
          "#{var_value_exact} OR #{var_value_grid} OR #{value_exact} OR #{value_grid}"
        else
          # No variable: match by value+payload
          "#{value_exact} OR #{value_grid}"
        end
      elsif variable.nil?
        # No value, no variable: match by payload only
        "(reflection_item->>'payload' = #{escaped_payload} OR reflection_item->>'payload' LIKE #{escaped_payload_like})"
      else
        # No value but has variable: match by variable+payload (legacy behavior)
        escaped_var = ActiveRecord::Base.connection.quote(variable)
        var_exact = "(reflection_item->>'variable' = #{escaped_var} AND reflection_item->>'payload' = #{escaped_payload})"
        var_grid = "(reflection_item->>'variable' = #{escaped_var} AND reflection_item->>'payload' LIKE #{escaped_payload_like})"
        no_var_exact = "(reflection_item->>'variable' IS NULL AND reflection_item->>'payload' = #{escaped_payload})"
        no_var_grid = "(reflection_item->>'variable' IS NULL AND reflection_item->>'payload' LIKE #{escaped_payload_like})"
        "#{var_exact} OR #{var_grid} OR #{no_var_exact} OR #{no_var_grid}"
      end
    end.join(' OR ')
  end

  def normalize_column_changes(changes)
    changes.transform_values do |change_hash|
      {
        'old' => normalize_payload(change_hash['old']),
        'new' => normalize_payload(change_hash['new'])
      }
    end
  end

  def build_column_update_cases(normalized_changes)
    normalized_changes.map do |column_value, change_hash|
      old_payload = change_hash['old']
      new_payload = change_hash['new']

      escaped_value = ActiveRecord::Base.connection.quote(column_value)
      escaped_old = ActiveRecord::Base.connection.quote(old_payload)
      escaped_new = ActiveRecord::Base.connection.quote(new_payload)

      # Match reflections that:
      # 1. Have this column value
      # 2. Have payload ending with " - <old_column_payload>"
      <<~SQL.squish
        WHEN reflection_item->>'value' = #{escaped_value}
          AND reflection_item->>'payload' LIKE '% - ' || #{escaped_old}
        THEN jsonb_set(
          reflection_item,
          '{payload}',
          to_jsonb(
            split_part(reflection_item->>'payload', ' - ', 1) || ' - ' || #{escaped_new}
          )
        )
      SQL
    end.join(' ')
  end
end
# rubocop:enable Metrics/ModuleLength
