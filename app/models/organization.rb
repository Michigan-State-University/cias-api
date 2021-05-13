# frozen_string_literal: true

class Organization < ApplicationRecord
  has_many :e_intervention_admins, -> { limit_to_roles('e_intervention_admin') }, class_name: 'User', as: :organizable
  has_many :organization_admins, -> { limit_to_roles('organization_admin') }, class_name: 'User', as: :organizable
  has_many :health_systems, dependent: :destroy
  has_many :health_clinics, through: :health_systems
  has_many :organization_invitations, dependent: :destroy
  has_one :reporting_dashboard, dependent: :destroy
  has_many :chart_statistics, through: :health_systems

  validates :name, presence: true, uniqueness: true

  after_create :initialize_reporting_dashboard

  default_scope { order(:name) }

  private

  def initialize_reporting_dashboard
    self.reporting_dashboard = ReportingDashboard.new
  end
end
