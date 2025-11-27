# frozen_string_literal: true

class V1::Question::AnswerOptionsChangeDetectors::GridDetector < V1::Question::AnswerOptionsChangeDetectors::BaseDetector
  def detect_changes(old_options, new_options)
    changes = []
    common_size = [old_options.size, new_options.size].min

    old_options.first(common_size).each_with_index do |old_opt, idx|
      old_var = old_opt['name']
      old_payload = old_opt['payload']
      old_value = old_opt['value']

      matched_option = if old_var.present?
                         new_options.find { |new_opt| new_opt['name'] == old_var } ||
                           new_options[idx]
                       elsif old_payload.blank? && old_value.present?
                         new_options.find { |new_opt| new_opt['value'] == old_value } ||
                           new_options[idx]
                       else
                         new_options[idx]
                       end

      next unless matched_option

      new_payload = matched_option['payload']
      new_value = matched_option['value']
      new_var = matched_option.dig('variable', 'name')

      next if old_payload == new_payload
      next if old_payload.blank? && new_payload.blank?

      changes << {
        'variable' => old_var,
        'new_variable' => new_var,
        'old_payload' => old_payload,
        'new_payload' => new_payload,
        'value' => old_value,
        'new_value' => new_value
      }.compact
    end

    changes
  end

  def detect_new_options(old_options, new_options)
    return [] unless new_options.size > old_options.size

    new_options[old_options.size..].map do |new_opt|
      payload = new_opt['payload']
      actual_payload = payload.presence || ''

      {
        'variable' => nil,
        'payload' => actual_payload
      }
    end
  end

  def detect_deleted_options(old_options, new_options)
    results = []

    return results unless old_options.size > new_options.size

    old_options.each do |old_opt|
      old_var = old_opt['name']
      old_payload = old_opt['payload']
      next if old_payload.blank?

      still_exists = if old_var.present?
                       new_options.any? { |new_opt| new_opt['name'] == old_var }
                     else
                       new_options.any? { |new_opt| new_opt['payload'] == old_payload }
                     end

      next if still_exists

      results << {
        'variable' => nil,
        'payload' => old_payload
      }
    end

    results
  end

  def detect_column_changes(old_columns, new_columns)
    # Check if there are duplicate values in old or new columns
    # If so, we must use payload matching instead of value matching
    use_payload_matching = duplicate_values?(old_columns) || duplicate_values?(new_columns)

    return detect_column_changes_by_payload(old_columns, new_columns) if use_payload_matching

    # Safe to use value-based matching when no duplicates
    old_map = old_columns.index_by { |col| col['value'] }
    new_map = new_columns.index_by { |col| col['value'] }

    changes = {}

    old_map.each do |value, old_col|
      new_col = new_map[value]
      next if new_col.nil?

      old_payload = old_col['payload']
      new_payload = new_col['payload']

      next if old_payload == new_payload
      next if old_payload.blank? && new_payload.blank?

      changes[value] = { 'old' => old_payload, 'new' => new_payload }
    end

    changes
  end

  def detect_new_columns(old_columns, new_columns)
    # Check if there are duplicate values
    use_payload_matching = duplicate_values?(old_columns) || duplicate_values?(new_columns)

    return detect_new_columns_by_payload(old_columns, new_columns) if use_payload_matching

    # Safe to use value-based matching when no duplicates
    old_values = old_columns.pluck('value')
    new_map = new_columns.index_by { |col| col['value'] }

    new_cols = {}
    new_map.each do |value, col|
      next if old_values.include?(value)

      new_cols[value] = col['payload']
    end

    new_cols
  end

  def detect_deleted_columns(old_columns, new_columns)
    # Check if there are duplicate values
    use_payload_matching = duplicate_values?(old_columns) || duplicate_values?(new_columns)

    return detect_deleted_columns_by_payload(old_columns, new_columns) if use_payload_matching

    # Safe to use value-based matching when no duplicates
    new_values = new_columns.pluck('value')
    old_map = old_columns.index_by { |col| col['value'] }

    deleted_cols = {}
    old_map.each do |value, col|
      next if new_values.include?(value)

      deleted_cols[value] = col['payload']
    end

    deleted_cols
  end

  private

  def detect_column_changes_by_payload(old_columns, new_columns)
    changes = {}
    remaining_new_columns = new_columns.dup

    old_columns.each do |old_col|
      old_value = old_col['value']
      old_payload = old_col['payload']

      # Match by payload when duplicate values exist
      match = remaining_new_columns.find { |new_col| new_col['payload'] == old_payload }

      next unless match

      remaining_new_columns.delete_at(remaining_new_columns.index(match))
      new_payload = match['payload']

      next if old_payload == new_payload
      next if old_payload.blank? && new_payload.blank?

      changes[old_value] = { 'old' => old_payload, 'new' => new_payload }
    end

    changes
  end

  def detect_new_columns_by_payload(old_columns, new_columns)
    new_cols = {}
    old_payloads = old_columns.pluck('payload')

    new_columns.each do |new_col|
      next if old_payloads.include?(new_col['payload'])

      new_cols[new_col['value']] = new_col['payload']
    end

    new_cols
  end

  def detect_deleted_columns_by_payload(old_columns, new_columns)
    deleted_cols = {}
    new_payloads = new_columns.pluck('payload')

    old_columns.each do |old_col|
      next if new_payloads.include?(old_col['payload'])

      deleted_cols[old_col['value']] = old_col['payload']
    end

    deleted_cols
  end
end
