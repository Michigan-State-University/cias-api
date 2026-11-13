# frozen_string_literal: true

class V1::PredefinedParticipants::SmsCampaigns::PayloadValidator
  CREATABLE_KINDS = %w[invitation manual_reminder].freeze

  def self.call(attributes)
    new(attributes).validate!
  end

  def initialize(attributes)
    @attributes = attributes
  end

  def validate!
    codes = payload_codes
    return if codes.empty?

    raise ComplexException.new(
      I18n.t('predefined_participants.sms_campaigns.errors.invalid_payload'),
      { errors: codes.map { |code| { code: code } } },
      :unprocessable_content
    )
  end

  private

  attr_reader :attributes

  def payload_codes
    codes = []
    codes << 'INVALID_KIND' unless CREATABLE_KINDS.include?(attributes.kind)
    codes.concat(text_codes(attributes.body, attributes.links))
    codes.concat(reminder_codes)
    codes
  end

  def reminder_codes
    return [] if attributes.reminder.blank?
    return ['SCHEDULED_REMINDER_NOT_ALLOWED'] unless attributes.kind == 'invitation'

    codes = text_codes(attributes.reminder_body, attributes.reminder_links).map { |code| "SCHEDULED_REMINDER_#{code}" }
    codes.unshift('INVALID_DAYS_AFTER') unless (1..Settings.sms_campaigns.max_reminder_days_after).cover?(attributes.days_after)
    codes
  end

  def text_codes(body, links)
    V1::PredefinedParticipants::SmsCampaigns::TextCodes.call(body, links)
  end
end
