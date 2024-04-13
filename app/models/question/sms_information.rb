# frozen_string_literal: true

class Question::SmsInformation < Question
  attribute :subtitle, :string, default: I18n.t('question.sms.initial.title')
  attribute :settings, :json, default: -> { {
    "image": false,
    "title": false,
    "video": false,
    "required": false,
    "subtitle": true,
    "proceed_button": false,
    "narrator_skippable": false,
    "start_autofinish_timer": false
  } }

  attribute :sms_schedule, :jsonb, default: {}
  validates :sms_schedule,
            json: { schema: -> { Rails.root.join('db/schema/_common/sms_schedule.json').to_s },
                    message: ->(err) { err } },
            if: -> { question_group&.sms_schedule.blank? }

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

  def assign_default_title_and_subtitle
    return unless new_record?
    return true unless question_group

    language_code = session.intervention.google_language&.language_code
    return unless language_code.in?(%w[ar es])

    self.subtitle = I18n.with_locale(language_code) { I18n.t('question.sms.initial.title') }
  end

  def schedule_at
    proper_schedule = sms_schedule || question_group.sms_schedule

    case proper_schedule['period']
    when 'monthly'
      date = DateTime.now.beginning_of_month + (proper_schedule['day_of_period'].to_i - 1).days

      datetime = if proper_schedule['time']['exact']
                   DateTime.parse(proper_schedule['time']['exact']).change(year: date.year, month: date.month, day: date.day)
                 else
                   from = DateTime.parse(proper_schedule['time']['range']['from']).change(year: date.year, month: date.month, day: date.day)
                   to = DateTime.parse(proper_schedule['time']['range']['to']).change(year: date.year, month: date.month, day: date.day)
                   rand(from..to)
                 end

      datetime += 1.month if datetime < DateTime.current
      datetime
    when 'weekly'
      date = DateTime.now.beginning_of_week(sms_schedule['day_of_period'].to_sym)

      datetime = if proper_schedule['time']['exact']
                   DateTime.parse(proper_schedule['time']['exact']).change(year: date.year, month: date.month, day: date.day)
                 else
                   from = DateTime.parse(proper_schedule['time']['range']['from']).change(year: date.year, month: date.month, day: date.day)
                   to = DateTime.parse(proper_schedule['time']['range']['to']).change(year: date.year, month: date.month, day: date.day)
                   rand(from..to)
                 end

      datetime += 1.week if datetime < DateTime.current
      datetime
    when 'daily'
      datetime = if proper_schedule['time']['exact']
                   DateTime.parse(proper_schedule['time']['exact'])
                 else
                   from = DateTime.parse(proper_schedule['time']['range']['from'])
                   to = DateTime.parse(proper_schedule['time']['range']['to'])
                   rand(from..to)
                 end
      datetime += 1.day if datetime < DateTime.current
      datetime
    end
  end
end
