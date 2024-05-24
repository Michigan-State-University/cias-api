# frozen_string_literal: true

class SmsLink < ApplicationRecord
  # ASSOCIATIONS
  belongs_to :sms_plan
  belongs_to :session
  has_many :sms_links_users, dependent: :destroy

  # VALIDATIONS
  validates :url, :variable_number, presence: true

  # ENUMS
  enum link_type: {
    website: 'website',
    video: 'video'
  }

  # CALLBACKS
  before_validation :set_session_id
  before_validation :set_variable_number

  # METHODS
  def set_session_id
    self.session_id ||= sms_plan&.session_id
  end

  def set_variable_number
    last_number = sms_plan.sms_links.pluck(:variable_number).last.to_i
    self.variable_number = last_number + 1
  end
end
