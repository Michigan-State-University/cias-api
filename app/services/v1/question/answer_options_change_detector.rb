# frozen_string_literal: true

# rubocop:disable Metrics/ClassLength
class V1::Question::AnswerOptionsChangeDetector
  attr_reader :question

  def initialize(question)
    @question = question
  end

  def detect_changes(old_options, new_options)
    case question
    when ::Question::Single
      result = compute_single_changes(old_options, new_options)
    when ::Question::Multiple
      result = compute_multiple_changes(old_options, new_options)
    when ::Question::Grid
      result = compute_grid_row_changes(old_options, new_options)
    else
      result = []
    end
    result
  end

  def detect_new_options(old_options, new_options)
    case question
    when ::Question::Single
      result = compute_new_single_options(old_options, new_options)
    when ::Question::Multiple
      result = compute_new_multiple_options(old_options, new_options)
    when ::Question::Grid
      result = compute_new_grid_rows(old_options, new_options)
    else
      result = []
    end
    result
  end

  def detect_deleted_options(old_options, new_options)
    case question
    when ::Question::Single
      result = compute_deleted_single_options(old_options, new_options)
    when ::Question::Multiple
      result = compute_deleted_multiple_options(old_options, new_options)
    when ::Question::Grid
      result = compute_deleted_grid_rows(old_options, new_options)
    else
      result = []
    end
    result
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

  def detect_new_columns_by_payload(old_columns, new_columns)
    new_cols = {}
    old_payloads = old_columns.pluck('payload')

    new_columns.each do |new_col|
      next if old_payloads.include?(new_col['payload'])

      new_cols[new_col['value']] = new_col['payload']
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

  def detect_deleted_columns_by_payload(old_columns, new_columns)
    deleted_cols = {}
    new_payloads = new_columns.pluck('payload')

    old_columns.each do |old_col|
      next if new_payloads.include?(old_col['payload'])

      deleted_cols[old_col['value']] = old_col['payload']
    end

    deleted_cols
  end

  private

  def compute_single_changes(old_options, new_options)
    changes = []
    var_name = old_options.first&.dig('name')
    remaining_new_options = new_options.dup

    # Check if there are duplicate values in old or new options
    # If so, we must use payload matching only
    use_payload_matching = duplicate_values?(old_options) || duplicate_values?(new_options)

    old_options.each do |old_opt|
      old_payload = old_opt['payload']
      old_value = old_opt['value']

      matched_option = find_matching_single_option(old_payload, old_value, remaining_new_options, use_payload_matching)

      next unless matched_option

      # Remove matched option from pool to prevent re-matching
      remaining_new_options.delete_at(remaining_new_options.index(matched_option))

      record_single_change(changes, var_name, old_opt, matched_option, use_payload_matching)
    end

    changes
  end

  def find_matching_single_option(old_payload, old_value, new_options, use_payload_matching = false)
    unless use_payload_matching
      # Priority 1: Match by value
      # Only use this if we know there are no duplicate values in old or new options
      match_by_value = new_options.find { |opt| opt['value'] == old_value }
      return match_by_value if match_by_value
    end

    # Priority 2: Match by payload (fallback or when duplicate values exist)
    # Only use this if payload is not blank
    if old_payload.present?
      matches_by_payload = new_options.select { |opt| opt['payload'] == old_payload }
      # Return match only if it's unique
      return matches_by_payload.first if matches_by_payload.size == 1
    end

    nil
  end

  def duplicate_values?(options)
    value_counts = options.each_with_object(Hash.new(0)) { |opt, counts| counts[opt['value']] += 1 }
    value_counts.values.any? { |count| count > 1 }
  end

  def record_single_change(changes, var_name, old_opt, matched_opt, use_payload_matching)
    old_payload = old_opt['payload']
    old_value = old_opt['value']
    new_payload = matched_opt['payload']
    new_value = matched_opt['value']

    return if old_payload == new_payload && old_value == new_value

    changes << {
      'variable' => var_name,
      'old_payload' => old_payload,
      'new_payload' => new_payload,
      'value' => use_payload_matching ? nil : old_value,
      'new_value' => use_payload_matching ? nil : new_value
    }
  end

  def compute_multiple_changes(old_options, new_options)
    changes = []
    remaining_new_options = new_options.dup

    # Check if there are duplicate values in old or new options
    # If so, we must skip value matching
    use_value_matching = !duplicate_values?(old_options) && !duplicate_values?(new_options)

    old_options.each do |old_opt|
      old_var = old_opt['name']
      old_payload = old_opt['payload']
      old_value = old_opt['value']

      matched_option = find_matching_multiple_option(old_opt, remaining_new_options, use_value_matching)
      next unless matched_option

      # Remove matched option from pool to prevent re-matching
      remaining_new_options.delete_at(remaining_new_options.index(matched_option))

      new_var = matched_option['name']
      new_payload = matched_option['payload']
      new_value = matched_option['value']

      payload_changed = old_payload != new_payload
      variable_changed = old_var != new_var
      value_changed = old_value != new_value

      next unless payload_changed || variable_changed || value_changed

      changes << {
        'variable' => old_var,
        'new_variable' => (new_var if variable_changed),
        'old_payload' => old_payload,
        'new_payload' => new_payload,
        'value' => use_value_matching ? old_value : nil,
        'new_value' => use_value_matching && value_changed ? new_value : nil
      }.compact
    end

    changes
  end

  def find_matching_multiple_option(old_opt, new_options, use_value_matching = true)
    old_var = old_opt['name']
    old_payload = old_opt['payload']
    old_value = old_opt['value']

    # Priority 1: Match by variable
    if old_var.present?
      match_by_var = new_options.find { |opt| opt['name'] == old_var }
      return match_by_var if match_by_var
    end

    # Priority 2: Match by value
    # Skip if duplicate values exist
    if use_value_matching
      match_by_value = new_options.find { |opt| opt['value'] == old_value }
      return match_by_value if match_by_value
    end

    # Priority 3: Match by payload
    return nil if old_payload.blank?

    matches_by_payload = new_options.select { |opt| opt['payload'] == old_payload }

    # Return match only if it's unique, otherwise nil
    matches_by_payload.size == 1 ? matches_by_payload.first : nil
  end

  def compute_grid_row_changes(old_options, new_options)
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

  def compute_new_single_options(old_options, new_options)
    var_name = new_options.first&.dig('name')
    return [] unless new_options.size > old_options.size

    new_options[old_options.size..].map do |new_opt|
      {
        'variable' => var_name,
        'payload' => new_opt['payload'],
        'value' => new_opt['value'].to_s
      }
    end
  end

  def compute_new_multiple_options(old_options, new_options)
    return [] unless new_options.size > old_options.size

    new_options[old_options.size..].map do |new_opt|
      {
        'variable' => new_opt['name'],
        'payload' => new_opt['payload'],
        'value' => new_opt['value'].to_s
      }
    end
  end

  def compute_new_grid_rows(old_options, new_options)
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

  def compute_deleted_single_options(old_options, new_options)
    results = []
    var_name = old_options.first&.dig('name')
    remaining_new_options = new_options.dup

    # Check if there are duplicate values in old or new options
    # If so, we must use payload matching only
    use_payload_matching = duplicate_values?(old_options) || duplicate_values?(new_options)

    old_options.each do |old_opt|
      payload = old_opt['payload']
      value = old_opt['value']

      match = find_matching_single_option(payload, value, remaining_new_options, use_payload_matching)

      if match
        # Remove matched option from pool to prevent re-matching
        remaining_new_options.delete_at(remaining_new_options.index(match))
        next
      end

      next if payload.blank?

      results << {
        'variable' => var_name,
        'payload' => payload,
        'value' => use_payload_matching ? nil : value
      }
    end

    results
  end

  def compute_deleted_multiple_options(old_options, new_options)
    results = []
    remaining_new_options = new_options.dup

    # Check if there are duplicate values in old or new options
    # If so, we must skip value matching
    use_value_matching = !duplicate_values?(old_options) && !duplicate_values?(new_options)

    old_options.each do |old_opt|
      var_name = old_opt['name']
      payload = old_opt['payload']
      value = old_opt['value']

      match = find_matching_multiple_option(old_opt, remaining_new_options, use_value_matching)

      if match
        # Remove the matched option so it can't be matched again
        remaining_new_options.delete_at(remaining_new_options.index(match))
        next
      end

      next if payload.blank?

      results << {
        'variable' => var_name,
        'payload' => payload,
        'value' => use_value_matching ? value : nil
      }
    end

    results
  end

  def compute_deleted_grid_rows(old_options, new_options)
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
end
# rubocop:enable Metrics/ClassLength
