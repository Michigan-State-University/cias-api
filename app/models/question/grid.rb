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
      variable_name = row.dig(:variable, :name)
      { 'name' => variable_name } if variable_name.present?
    end
  end

  def question_answers
    rows = body.dig('data', 0, 'payload', 'rows')
    map_rows_to_answers(rows)
  end

  def extract_answers_from_params(params)
    rows = params.dig(:body, :data, 0, :payload, :rows)
    map_rows_to_answers(rows)
  end

  def question_columns
    columns = body.dig('data', 0, 'payload', 'columns')
    map_columns_to_hash(columns)
  end

  def extract_columns_from_params(params)
    columns = params.dig(:body, :data, 0, :payload, :columns)
    map_columns_to_hash(columns)
  end

  private

  def map_rows_to_answers(rows)
    return [] if rows.blank?

    rows.map do |row|
      var_name = row.dig('variable', 'name').presence || row.dig(:variable, :name).presence
      payload_text = row['payload'] || row[:payload]
      value = row['value'] || row[:value]

      { 'name' => var_name, 'payload' => payload_text, 'value' => value }
    end
  end

  def map_columns_to_hash(columns)
    return [] if columns.blank?

    columns.map do |col|
      value = col.dig('variable', 'value') || col.dig(:variable, :value)
      payload_text = col['payload'] || col[:payload]

      { 'value' => value, 'payload' => payload_text }
    end
  end
end
