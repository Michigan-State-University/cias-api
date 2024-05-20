# frozen_string_literal: true

class SmsLink < ApplicationRecord
  # ASSOCIATIONS
  belongs_to :sms_plan
  belongs_to :session

  # VALIDATIONS
  validates :url, :variable, presence: true

  # ENUMS
  enum type: {
    website: 'website',
    video: 'video'
  }

  # CALLBACKS
  before_validation :set_session_id

  # METHODS
  def set_session_id
    self.session_id ||= sms_plan&.session_id
  end

  def add_timestamp
    entered_timestamps << Time.current
    save!
  end
end
