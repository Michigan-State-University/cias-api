# frozen_string_literal: true

class HealthSystem < ApplicationRecord
  belongs_to :organization
  has_many :health_clinics, dependent: :destroy
  has_many :health_system_invitations, dependent: :destroy
  has_many :health_system_admins, -> { limit_to_roles('health_system_admin') }, class_name: 'User', as: :organizable

  validates :name, presence: true, uniqueness: { scope: :organization }

  default_scope { order(:name) }
end
