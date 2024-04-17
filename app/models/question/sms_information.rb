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

  def schedule_in(user_session)
    proper_schedule = sms_schedule
    last_item_datetime = case proper_schedule['period']
                         when 'from_last_question'
                           if user_session.answers.any?
                             user_session.answers.last&.created_at
                           else
                             user_session.created_at
                           end
                         when 'from_user_session_start'
                           user_session.created_at
                         when 'monthly'
                           date = DateTime.current + proper_schedule['day_of_period'].to_i.days

                           datetime = if proper_schedule['time']['exact']
                                        DateTime.parse(proper_schedule['time']['exact']).change(year: date.year, month: date.month, day: date.day)
                                      else
                                        from = DateTime.parse(proper_schedule['time']['range']['from']).change(year: date.year, month: date.month,
                                                                                                               day: date.day)
                                        to = DateTime.parse(proper_schedule['time']['range']['to']).change(year: date.year, month: date.month, day: date.day)
                                        rand(from..to)
                                      end

                           return datetime
                         when 'weekly'
                           date = DateTime.current

                           datetime = if proper_schedule['time']['exact']
                                        DateTime.parse(proper_schedule['time']['exact']).change(year: date.year, month: date.month, day: date.day)
                                      else
                                        from = DateTime.parse(proper_schedule['time']['range']['from']).change(year: date.year, month: date.month,
                                                                                                               day: date.day)
                                        to = DateTime.parse(proper_schedule['time']['range']['to']).change(year: date.year, month: date.month, day: date.day)
                                        rand(from..to)
                                      end

                           return datetime
                         else
                           DateTime.current
                         end

    date = last_item_datetime + proper_schedule['day_of_period'].to_i.day

    if proper_schedule['time']['exact']
      DateTime.parse(proper_schedule['time']['exact']).change(year: date.year, month: date.month, day: date.day)
    else
      from = DateTime.parse(proper_schedule['time']['range']['from']).change(year: date.year, month: date.month, day: date.day)
      to = DateTime.parse(proper_schedule['time']['range']['to']).change(year: date.year, month: date.month, day: date.day)
      rand(from..to)
    end
  end
end
