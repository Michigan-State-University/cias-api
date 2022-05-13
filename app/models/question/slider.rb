# frozen_string_literal: true

class Question::Slider < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'required' => true, 'show_number' => true }
    )
  end

  def variable_clone_prefix(taken_variables)
    return unless body['variable']['name'].presence

    new_variable = "clone_#{body['variable']['name']}"
    new_variable = variable_with_clone_index(taken_variables, body['variable']['name']) if taken_variables.include?(new_variable)
    body['variable']['name'] = new_variable
  end

  def translate_body(translator, source_language_name_short, destination_language_name_short)
    body['data'].each do |row|
      original_payload(row['payload'])

      row['payload']['end_value'] = translator.translate(row['payload']['end_value'], source_language_name_short, destination_language_name_short)
      row['payload']['start_value'] = translator.translate(row['payload']['start_value'], source_language_name_short, destination_language_name_short)
    end
  end

  def question_variables
    [body['variable']['name']]
  end

  private

  def original_payload(row)
    row['original_text'] = {
      'end_value' => row['end_value'],
      'start_value' => row['start_value']
    }
  end
end
