# frozen_string_literal: true

class Question::Feedback < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def prepare_to_display(answers_var_values)
    apply_formula(answers_var_values)
    self
  end

  def apply_formula(var_values)
    to_process = body_data[0]['spectrum']
    result = exploit_formula(
      var_values,
      to_process['payload'],
      to_process['patterns']
    )
    body_data[0]['payload']['target_value'] = result
  end

  def csv_header_names
    []
  end

  def translate_body(translator, source_language_name_short, destination_language_name_short)
    body['data'].each do |row|
      original_payload(row['payload'])

      row['payload']['end_value'] = translator.translate(row['payload']['end_value'], source_language_name_short, destination_language_name_short)
      row['payload']['start_value'] = translator.translate(row['payload']['start_value'], source_language_name_short, destination_language_name_short)
    end
  end

  private

  def original_payload(row)
    row['original_text'] = {
      'end_value' => row['end_value'],
      'start_value' => row['start_value']
    }
  end
end
