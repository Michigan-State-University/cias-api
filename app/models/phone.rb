# frozen_string_literal: true

class Phone < ApplicationRecord
  has_paper_trail skip: %i[number number_ciphertext migrated_number]
  has_many :alert_phones, dependent: :destroy
  has_many :sms_plans, through: :alert_phones
  belongs_to :user, optional: true
  belongs_to :navigator_setup, class_name: 'LiveChat::Interventions::NavigatorSetup', optional: true
  validates :iso, :prefix, presence: true
  # validate number only if its not an alert phone, because we need to allow blank values for updating when its an alert phone number
  # we disable validation on create to enable edition of alert phone numbers
  validates :number, presence: true, unless: :alert_phone_exists?, on: %i[save update]
  before_validation :normalize_number_parts
  validate :number_must_be_a_phone_number
  before_save :assign_sms_eligible
  before_update :remove_confirmation, if: :full_number_changed?

  enum :communication_way, { call: 'call', message: 'message' }

  audited except: %i[number number_ciphertext migrated_number]
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

  # Exclude migrated_number from audited changes
  def audited_changes(changes = nil)
    changes ||= super
    changes.except('migrated_number')
  end

  private

  def number_analysis
    Phone::NumberAnalysis.new(prefix, number)
  end

  def normalize_number_parts
    analysis = number_analysis
    return unless analysis.valid?

    assign_attributes(analysis.parts(with_iso: iso.present?).reject { |attribute, value| public_send(attribute) == value })
  end

  def full_number_changed?
    return false unless number_changed? || prefix_changed?

    previous = Phone::NumberAnalysis.new(prefix_was, number_was).e164
    previous.nil? || previous != number_analysis.e164
  end

  def number_must_be_a_phone_number
    return if number.blank? || prefix.blank?
    return unless new_record? || will_save_change_to_number? || will_save_change_to_prefix?

    errors.add(:number, :invalid) unless number_analysis.valid?
  end

  def assign_sms_eligible
    self.sms_eligible = number_analysis.sms_eligible?
  end

  def alert_phone_exists?
    alert_phones.size&.positive?
  end

  def remove_confirmation
    self.confirmed = false
    self.confirmed_at = nil
    self.confirmation_code = nil
  end
end
