# frozen_string_literal: true

class Question::BarGraph < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def variable_clone_prefix(taken_variables)
    return unless body['variable']['name'].presence

    new_variable = "clone_#{body['variable']['name']}"
    new_variable = variable_with_clone_index(taken_variables, body['variable']['name']) if taken_variables.include?(new_variable)
    body['variable']['name'] = new_variable
  end

  def question_variables
    [body['variable']['name']]
  end
end
