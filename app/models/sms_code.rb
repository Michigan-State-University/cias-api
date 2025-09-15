# frozen_string_literal: true

class SmsCode < ApplicationRecord
  SMS_CODE_MIN_LENGTH = 4
  TWILIO_SPECIAL_CODES = %w[STOP START].freeze

  has_paper_trail
  belongs_to :session, inverse_of: :sms_codes
  belongs_to :health_clinic, inverse_of: :sms_codes, optional: true

  validates :sms_code, uniqueness: true, presence: true, length: { minimum: SMS_CODE_MIN_LENGTH }, if: -> { active }
  validate :sms_code_cannot_be_protected_word, if: -> { active }

  def sms_code_cannot_be_protected_word
    return if sms_code.blank?
    return unless TWILIO_SPECIAL_CODES.any? { |v| sms_code.casecmp?(v) }

    errors.add(:sms_code, I18n.t('activerecord.errors.models.session.sms_code.attributes.sms_code.protected_code'))
  end
end
