# frozen_string_literal: true

class PredefinedUserParameter < ApplicationRecord
  include CappedSlug

  SLUG_LENGTH = 4

  belongs_to :user
  belongs_to :intervention
  belongs_to :health_clinic, optional: true
  has_many :sms_deliveries, class_name: 'PredefinedParticipants::SmsDelivery',
                            inverse_of: :predefined_user_parameter, dependent: :destroy

  validates :slug, uniqueness: true

  before_validation :generate_slug, on: :create

  def self.personal_link(slug, web_url = ENV.fetch('WEB_URL', nil))
    "#{web_url}/usr/#{slug}"
  end
end
