# frozen_string_literal: true

class SmsCode < ApplicationRecord
  SMS_CODE_MIN_LENGTH = 4

  has_paper_trail
  belongs_to :session, inverse_of: :sms_codes
  belongs_to :health_clinic, inverse_of: :sms_codes, required: false

  validates :sms_code, uniqueness: true, presence: true, length: { minimum: SMS_CODE_MIN_LENGTH }
end
