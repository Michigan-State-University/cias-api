# frozen_string_literal: true

class HealthSystem < ApplicationRecord
  has_paper_trail
  acts_as_paranoid

  belongs_to :organization
  has_many :health_clinics, -> { with_deleted }, dependent: :destroy
  has_many :health_system_invitations, dependent: :destroy
  has_many :health_system_admins, -> { limit_to_roles('health_system_admin') }, class_name: 'User', as: :organizable, dependent: nil
  has_many :chart_statistics, through: :health_clinics, dependent: nil

  validates :name, presence: true, uniqueness: { scope: :organization }

  default_scope { order(created_at: :desc) }
  before_destroy :deactivate_health_system_admins

  private

  def deactivate_health_system_admins
    health_system_admins.each(&:deactivate!)
    health_system_admins.delete_all
  end
end
