# frozen_string_literal: true

class V1::Question::AnswerOptionsChangeDetectors::MultipleDetector < V1::Question::AnswerOptionsChangeDetectors::BaseDetector
  def detect_changes(old_options, new_options)
    changes = []
    remaining_new_options = new_options.dup

    # Check if there are duplicate values in old or new options
    # If so, we must skip value matching
    use_value_matching = !duplicate_values?(old_options) && !duplicate_values?(new_options)

    old_options.each do |old_opt|
      old_var = old_opt['name']
      old_payload = old_opt['payload']
      old_value = old_opt['value']

      matched_option = find_matching_option(old_opt, remaining_new_options, use_value_matching)
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

  def detect_new_options(old_options, new_options)
    return [] unless new_options.size > old_options.size

    new_options[old_options.size..].map do |new_opt|
      {
        'variable' => new_opt['name'],
        'payload' => new_opt['payload'],
        'value' => new_opt['value'].to_s
      }
    end
  end

  def detect_deleted_options(old_options, new_options)
    results = []
    remaining_new_options = new_options.dup

    # Check if there are duplicate values in old or new options
    # If so, we must skip value matching
    use_value_matching = !duplicate_values?(old_options) && !duplicate_values?(new_options)

    old_options.each do |old_opt|
      var_name = old_opt['name']
      payload = old_opt['payload']
      value = old_opt['value']

      match = find_matching_option(old_opt, remaining_new_options, use_value_matching)

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

  private

  def find_matching_option(old_opt, new_options, use_value_matching = true)
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
end
