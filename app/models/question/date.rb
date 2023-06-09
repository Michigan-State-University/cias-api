# frozen_string_literal: true

class Question::Date < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'required' => true }
    )
  end

  def variable_clone_prefix(taken_variables)
    return unless body['variable']['name'].presence

    new_variable = "clone_#{body['variable']['name']}"
    if taken_variables.include?(new_variable)
      new_variable = variable_with_clone_index(taken_variables,
                                               body['variable']['name'])
    end
    body['variable']['name'] = new_variable
  end

  def question_variables
    [body['variable']['name']]
  end
end
