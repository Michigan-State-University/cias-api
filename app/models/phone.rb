# frozen_string_literal: true

class Phone < ApplicationRecord
  has_paper_trail skip: %i[number migrated_number]
  has_many :alert_phones, dependent: :destroy
  has_many :sms_plans, through: :alert_phones
  belongs_to :user, optional: true
  belongs_to :navigator_setup, class_name: 'LiveChat::Interventions::NavigatorSetup', optional: true
  validates :iso, :prefix, presence: true
  # validate number only if its not an alert phone, because we need to allow blank values for updating when its an alert phone number
  # we disable validation on create to enable edition of alert phone numbers
  validates :number, presence: true, unless: :alert_phone_exists?, on: %i[save update]
  before_update :remove_confirmation, if: :number_changed?

  enum communication_way: { call: 'call', message: 'message' }

  has_encrypted :number
  blind_index :number

  def token_correct?(code)
    code == confirmation_code
  end

  def refresh_confirmation_code
    update(confirmation_code: rand.to_s[2..5])
  end

  def confirmed?
    confirmed
  end

  def confirm!
    update(confirmed: true, confirmed_at: DateTime.current)
  end

  def full_number
    prefix + number
  end

  private

  def alert_phone_exists?
    alert_phones.size&.positive?
  end

  def remove_confirmation
    self.confirmed = false
    self.confirmed_at = nil
    self.confirmation_code = nil
  end
end
