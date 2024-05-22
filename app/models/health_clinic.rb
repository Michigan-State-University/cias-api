# frozen_string_literal: true

class HealthClinic < ApplicationRecord
  has_paper_trail
  acts_as_paranoid

  belongs_to :health_system
  has_many :health_clinic_invitations, dependent: :destroy
  has_many :user_health_clinics, dependent: :destroy
  has_many :health_clinic_admins, through: :user_health_clinics, source: :user
  has_many :chart_statistics, dependent: nil
  has_many :user_sessions, dependent: :destroy
  has_many :invitations, dependent: :destroy
  has_many :short_links, dependent: :destroy
  has_many :sms_codes, dependent: :nullify
  has_many :sms_sessions, through: :sms_codes

  validates :name, presence: true, uniqueness: { scope: :health_system }

  default_scope { order(created_at: :desc) }
  scope :active, -> { where(deleted_at: nil) }
end
