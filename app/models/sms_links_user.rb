# frozen_string_literal: true

class SmsLinksUser < ApplicationRecord
  # ASSOCIATIONS
  belongs_to :user
  belongs_to :sms_link

  # CALLBACKS
  before_create :generate_slug

  # VALIDATIONS
  validates :slug, uniqueness: true

  # METHODS
  def add_timestamp
    entered_timestamps << Time.current.strftime('%Y/%m/%d %H:%M:%S UTC')
    save!
  end

  def generate_slug(suggested_slug = nil)
    suggested_slug ||= SecureRandom.base58(5)

    if SmsLinksUser.where(slug: suggested_slug).any?
      generate_slug(suggested_slug + SecureRandom.base58(2))
    else
      self.slug = suggested_slug
    end
  end
end
