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

  attribute :sms_schedule, :jsonb, default: {
    period: 'from_last_question',
    day_of_period: '1',
    time: {
      exact: '8:00 AM'
    }
  }
  validates :sms_schedule,
            json: { schema: -> { Rails.root.join('db/schema/_common/sms_schedule.json').to_s },
                    message: ->(err) { err } },
            if: -> { question_group&.sms_schedule.blank? }

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
