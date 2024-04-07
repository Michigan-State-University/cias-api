# frozen_string_literal: true

class Question::SmsInformation < Question
  include ::Question::CloneableVariable

  attribute :title, :string, default: I18n.t('question.sms.initial.title')
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  before_validation :assign_default_title_and_subtitle

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

  def assign_default_title_and_subtitle
    return unless new_record?

    language_code = session.intervention.google_language&.language_code
    return unless language_code.in?(%w[ar es])

    self.title = I18n.with_locale(language_code) { I18n.t('question.sms.initial.title') }
  end
end
