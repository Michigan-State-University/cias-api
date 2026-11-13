# frozen_string_literal: true

class SmsLink < ApplicationRecord
  ALLOWED_URL_SCHEME = %r{\Ahttps?://.*\z}i
  TOKEN_PATTERN = /::([^:\s]+)::/

  def self.token(variable)
    "::#{variable}::"
  end

  belongs_to :sms_plan, optional: true
  belongs_to :session, optional: true
  belongs_to :variant, class_name: 'SmsPlan::Variant', optional: true
  belongs_to :campaign, class_name: 'PredefinedParticipants::SmsCampaign', optional: true, inverse_of: :sms_links
  has_many :sms_links_users, dependent: :destroy

  validates :url, :variable, presence: true
  validates :url, format: { with: ALLOWED_URL_SCHEME }, allow_blank: true
  validates :url, :variable, uniqueness: { scope: :sms_plan_id, conditions: -> { where(variant_id: nil) } },
                             if: -> { variant_id.nil? && !campaign_link? }
  validates :url, :variable, uniqueness: { scope: :variant_id },
                             if: -> { variant_id.present? && !campaign_link? }
  validates :variable, uniqueness: { scope: :campaign_id }, if: -> { campaign_id.present? }

  enum :link_type, {
    website: 'website',
    video: 'video'
  }

  # CALLBACKS
  before_validation :set_derived_ids
  before_validation :add_https_to_url

  def campaign_link?
    campaign_id.present? || campaign.present?
  end

  def set_derived_ids
    self.sms_plan_id ||= variant&.sms_plan_id
    self.session_id  ||= sms_plan&.session_id
  end

  def add_https_to_url
    return if url.blank?

    self.url = url.start_with?(%r{\A\w+://}) ? url : "https://#{url}"
  end
end
