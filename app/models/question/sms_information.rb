# frozen_string_literal: true

class Question::SmsInformation < Question
  attribute :subtitle, :string, default: I18n.t('question.sms.initial.title')
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
  validates :accepted_answers, absence: true

  before_validation :assign_default_subtitle

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

  def assign_default_subtitle
    return unless new_record?
    return true unless question_group

    language_code = session.intervention.google_language&.language_code
    return unless language_code.in?(%w[ar es])

    self.subtitle = I18n.with_locale(language_code) { I18n.t('question.sms.initial.title') }
  end
end
