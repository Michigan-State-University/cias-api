# frozen_string_literal: true

class Question::Slider < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  validate :correct_range_format, if: :body_changed?

  before_validation :change_range_to_integers, if: :body_changed?

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
      'range_end' => row['range_end'],
      'range_start' => row['range_start'],
      'end_value' => row['end_value'],
      'start_value' => row['start_value']
    }
  end

  def correct_range_format
    body['data'][0]['payload'].tap do |question_payload|
      return errors.add(:base, I18n.t('question.slider.invalid_range')) if question_payload['range_start'] >= question_payload['range_end']
    end
  end

  def change_range_to_integers
    question_payload = body['data'][0]['payload']
    assign_default_range_values!(question_payload) if question_payload['range_start'].blank? || question_payload['range_end'].blank?
    question_payload['range_start'] = Integer(question_payload['range_start'])
    question_payload['range_end'] = Integer(question_payload['range_end'])
  rescue ArgumentError
    raise ActiveRecord::ActiveRecordError, I18n.t('question.slider.range_value_not_a_number')
  end

  def assign_default_range_values!(payload)
    payload['range_start'] = 0
    payload['range_end'] = 100
  end
end
