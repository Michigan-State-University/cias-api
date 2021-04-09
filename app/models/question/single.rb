# frozen_string_literal: true

class Question::Single < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'proceed_button' => true, 'required' => true }
    )
  end

  def variable_clone_prefix(taken_variables)
    return unless body['variable']['name'].presence

    new_variable = "clone_#{body['variable']['name']}"
    new_variable = variable_with_clone_index(taken_variables, body['variable']['name']) if taken_variables.include?(new_variable)
    body['variable']['name'] = new_variable
  end
end
