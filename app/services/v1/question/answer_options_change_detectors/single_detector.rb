# frozen_string_literal: true

class V1::Question::AnswerOptionsChangeDetectors::SingleDetector < V1::Question::AnswerOptionsChangeDetectors::BaseDetector
  def detect_changes(old_options, new_options)
    changes = []
    var_name = old_options.first&.dig('name')
    remaining_new_options = new_options.dup

    # Check if there are duplicate values in old or new options
    # If so, we must use payload matching only
    use_payload_matching = duplicate_values?(old_options) || duplicate_values?(new_options)

    old_options.each do |old_opt|
      old_payload = old_opt['payload']
      old_value = old_opt['value']

      matched_option = find_matching_option(old_payload, old_value, remaining_new_options, use_payload_matching)

      next unless matched_option

      # Remove matched option from pool to prevent re-matching
      remaining_new_options.delete_at(remaining_new_options.index(matched_option))

      record_change(changes, var_name, old_opt, matched_option, use_payload_matching)
    end

    changes
  end

  def detect_new_options(old_options, new_options)
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

  def detect_deleted_options(old_options, new_options)
    results = []
    var_name = old_options.first&.dig('name')
    remaining_new_options = new_options.dup

    # Check if there are duplicate values in old or new options
    # If so, we must use payload matching only
    use_payload_matching = duplicate_values?(old_options) || duplicate_values?(new_options)

    old_options.each do |old_opt|
      payload = old_opt['payload']
      value = old_opt['value']

      match = find_matching_option(payload, value, remaining_new_options, use_payload_matching)

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

  private

  def find_matching_option(old_payload, old_value, new_options, use_payload_matching = false)
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

  def record_change(changes, var_name, old_opt, matched_opt, use_payload_matching)
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
end
