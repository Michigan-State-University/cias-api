# frozen_string_literal: true

class Question::Grid < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super.merge(
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
      new_variable = variable_with_clone_index(taken_variables, row['variable']['name']) if taken_variables.include?(new_variable)
      row['variable']['name'] = new_variable
    end
  end

  def translate_body(translator, source_language_name_short, destination_language_name_short)
    translate_table(body['data'].first['payload']['rows'], translator, source_language_name_short, destination_language_name_short)
    translate_table(body['data'].first['payload']['columns'], translator, source_language_name_short, destination_language_name_short)
  end

  def translate_table(table, translator, source_language_name_short, destination_language_name_short)
    table.each do |record|
      record['original_text'] = record['payload']
      translated_text = translator.translate(record['payload'], source_language_name_short, destination_language_name_short)
      record['payload'] = translated_text
    end
  end

  def question_variables
    body['data'].flat_map { |data| data['payload']['rows'].map { |row| row['variable']['name'] } }
  end

  def extract_variables_from_params(params)
    rows = params.dig(:body, :data, 0, :payload, :rows)
    return [] if rows.blank?

    rows.filter_map do |row|
      name = row.dig(:variable, :name)
      { 'name' => name } if name.present?
    end
  end
end
