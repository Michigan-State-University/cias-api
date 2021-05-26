# frozen_string_literal: true

class Question::Grid < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'proceed_button' => true, 'required' => true }
    )
  end

  def csv_header_names
    body_data.first['payload']['rows'].map { |row| row['variable']['name'] }
  end

  def variable_clone_prefix(taken_variables)
    body_data[0]['payload']['rows']&.each do |row|
      next unless row['variable']['name'].presence

      new_variable = "clone_#{row['variable']['name']}"
      if taken_variables.include?(new_variable)
        new_variable = variable_with_clone_index(taken_variables,
                                                 row['variable']['name'])
      end
      row['variable']['name'] = new_variable
    end
  end
end
