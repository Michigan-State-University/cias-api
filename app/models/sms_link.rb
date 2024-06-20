# frozen_string_literal: true

class SmsLink < ApplicationRecord
  # ASSOCIATIONS
  belongs_to :sms_plan
  belongs_to :session
  has_many :sms_links_users, dependent: :destroy

  # VALIDATIONS
  validates :url, :variable, presence: true, uniqueness: { scope: :sms_plan_id }

  # ENUMS
  enum link_type: {
    website: 'website',
    video: 'video'
  }

  # CALLBACKS
  before_validation :set_session_id
  before_validation :add_https_to_url

  # METHODS
  def set_session_id
    self.session_id ||= sms_plan&.session_id
  end

  def add_https_to_url
    return if url.blank?

    self.url = url.start_with?('http') ? url : "https://#{url}"
  end
end
