# frozen_string_literal: true

class SmsLinksUser < ApplicationRecord
  include CappedSlug

  SLUG_LENGTH = 5

  belongs_to :user
  belongs_to :sms_link

  before_validation :generate_slug, on: :create

  validates :slug, uniqueness: true

  def self.tracked_link(slug, web_url = ENV.fetch('WEB_URL', nil))
    "#{web_url}/link/#{slug}"
  end

  def add_timestamp
    entered_timestamps << Time.current.strftime('%Y-%m-%d %H:%M:%S UTC')
    save!
  end
end
