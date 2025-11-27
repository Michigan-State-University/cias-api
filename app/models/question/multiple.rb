# frozen_string_literal: true

class Question::Multiple < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  def self.assign_default_values(attr)
    super.merge(
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
      new_variable = variable_with_clone_index(taken_variables, payload['variable']['name']) if taken_variables.include?(new_variable)
      payload['variable']['name'] = new_variable
    end
  end

  def translate_body(translator, source_language_name_short, destination_language_name_short)
    body['data'].each do |row|
      row['original_text'] = row['payload']

      translated_text = translator.translate(row['payload'], source_language_name_short, destination_language_name_short)
      row['payload'] = translated_text
    end
  end

  def question_variables
    body['data'].map { |data| data['variable']['name'] }
  end

  def extract_variables_from_params(params)
    data = params.dig(:body, :data)
    return [] if data.blank?

    data.filter_map do |row|
      variable_name = row.dig(:variable, :name)
      { 'name' => variable_name } if variable_name.present?
    end
  end

  def question_answers
    data = body['data']
    map_rows_to_answers(data)
  end

  def extract_answers_from_params(params)
    source_body = params[:body]
    return [] if source_body.blank?

    data = source_body[:data]
    map_rows_to_answers(data)
  end

  private

  def map_rows_to_answers(data)
    return [] if data.blank?

    data.map do |row|
      var_name = row.dig('variable', 'name').presence || row.dig(:variable, :name).presence
      payload_text = row['payload'] || row[:payload]
      value = row.dig('variable', 'value') || row.dig(:variable, :value)

      { 'name' => var_name, 'payload' => payload_text, 'value' => value }
    end
  end
end
