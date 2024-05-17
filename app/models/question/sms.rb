# frozen_string_literal: true

class Question::Sms < Question
  include ::Question::CloneableVariable

  attribute :settings, :json, default: lambda {
                                         {
                                           image: false,
                                           title: false,
                                           video: false,
                                           required: false,
                                           subtitle: true,
                                           proceed_button: false,
                                           narrator_skippable: false,
                                           start_autofinish_timer: false
                                         }
                                       }

  attribute :accepted_answers, :json, default: -> { {} }

  validates :accepted_answers, json: { schema: lambda {
    Rails.root.join("#{json_schema_path}/accepted_answers.json").to_s
  }, message: lambda { |err|
    err
  } }, allow_blank: true

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'proceed_button' => false, 'required' => false }
    )
  end

  def translate_body(translator, source_language_name_short, destination_language_name_short)
    body['data'].each do |row|
      row['original_text'] = row['payload']

      translated_text = translator.translate(row['payload'], source_language_name_short, destination_language_name_short)
      row['payload'] = translated_text
    end
  end

  def question_variables
    [body['variable']['name']]
  end
end
