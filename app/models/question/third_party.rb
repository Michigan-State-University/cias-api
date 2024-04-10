# frozen_string_literal: true

class Question::ThirdParty < Question
  attribute :settings, :json, default: -> { assign_default_values('settings') }

  validates :sms_schedule, absence: true

  before_save :downcase_third_party_emails

  def self.assign_default_values(attr)
    super(attr).merge(
      { 'required' => false }
    )
  end

  def question_variables
    [body['variable']['name']]
  end

  def translate_body(translator, source_language_name_short, destination_language_name_short)
    body['data'].each do |row|
      row['original_text'] = row['payload']

      row['payload'] = translator.translate(row['payload'], source_language_name_short, destination_language_name_short)
    end
  end

  private

  def downcase_third_party_emails
    body['data'].each do |data|
      data['value'] = data['value'].downcase if /[[:upper:]]/.match?(data['value'])
    end
  end
end
