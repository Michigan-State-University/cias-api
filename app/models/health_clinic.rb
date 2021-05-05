# frozen_string_literal: true

class HealthClinic < ApplicationRecord
  belongs_to :health_system
  has_many :health_clinic_invitations, dependent: :destroy
  has_many :health_clinic_admins, -> { limit_to_roles('health_clinic_admin') }, class_name: 'User', as: :organizable

  validates :name, presence: true, uniqueness: { scope: :health_system }

  default_scope { order(:name) }
end
