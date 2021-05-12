# frozen_string_literal: true

class HealthClinic < ApplicationRecord
  belongs_to :health_system
  has_many :health_clinic_invitations, dependent: :destroy
  has_many :health_clinic_admins, -> { limit_to_roles('health_clinic_admin') }, class_name: 'User', as: :organizable
  has_many :user_health_clinics, dependent: :destroy
  has_many :user_sessions, dependent: :destroy
  has_many :invitations, dependent: :destroy

  validates :name, presence: true, uniqueness: { scope: :health_system }

  default_scope { order(created_at: :desc) }
end
