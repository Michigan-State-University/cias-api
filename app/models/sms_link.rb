# frozen_string_literal: true

class SmsLink < ApplicationRecord
  # ASSOCIATIONS
  belongs_to :sms_plan
  belongs_to :session
  belongs_to :variant, class_name: 'SmsPlan::Variant', optional: true
  has_many :sms_links_users, dependent: :destroy

  # VALIDATIONS
  validates :url, :variable, presence: true
  validates :url, :variable, uniqueness: { scope: :sms_plan_id, conditions: -> { where(variant_id: nil) } },
                             if: -> { variant_id.nil? }
  validates :url, :variable, uniqueness: { scope: :variant_id },
                             if: -> { variant_id.present? }

  # ENUMS
  enum :link_type, {
    website: 'website',
    video: 'video'
  }

  # CALLBACKS
  before_validation :set_derived_ids
  before_validation :add_https_to_url

  # METHODS
  def set_derived_ids
    self.sms_plan_id ||= variant&.sms_plan_id
    self.session_id  ||= sms_plan&.session_id
  end

  def add_https_to_url
    return if url.blank?

    self.url = url.start_with?(%r{\A\w+://}) ? url : "https://#{url}"
  end
end
