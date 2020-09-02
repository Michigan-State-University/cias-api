# frozen_string_literal: true

class Question::Feedback < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def apply_formula(var_values)
    to_process = body_data[0]['spectrum']
    result = exploit_formula(
      var_values,
      to_process['payload'],
      to_process['patterns']
    )
    body_data[0]['payload']['target_value'] = result
  end
end
