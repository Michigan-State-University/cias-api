# frozen_string_literal: true

class Question::Multiple < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'required' => true }
    )
  end

  def csv_header_names
    body_data.map { |payload| payload['variable']['name'] }
  end

  def variable_clone_prefix(taken_variables)
    body_data&.each do |payload|
      next unless payload['variable']['name'].presence

      new_variable = "clone_#{payload['variable']['name']}"
      if taken_variables.include?(new_variable)
        new_variable = variable_with_clone_index(taken_variables,
                                                 payload['variable']['name'])
      end
      payload['variable']['name'] = new_variable
    end
  end
end
