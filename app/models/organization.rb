# frozen_string_literal: true

class Organization < ApplicationRecord
  has_paper_trail
  has_many :organization_admins, -> { limit_to_roles('organization_admin') }, class_name: 'User', as: :organizable, dependent: nil
  has_many :health_systems, -> { with_deleted }, dependent: :destroy
  has_many :health_clinics, -> { with_deleted }, through: :health_systems
  has_many :organization_invitations, dependent: :destroy
  has_one :reporting_dashboard, dependent: :destroy
  has_many :charts, through: :reporting_dashboard
  has_many :chart_statistics, through: :health_systems
  has_many :e_intervention_admin_organizations, dependent: :destroy
  has_many :e_intervention_admins, through: :e_intervention_admin_organizations, source: :user

  validates :name, presence: true, uniqueness: true

  after_create :initialize_reporting_dashboard
  before_destroy :deactivate_organization_and_intervention_admins, :update_interventions_from_deleted_organization, :really_destroy_all_children

  default_scope { order(created_at: :desc) }

  private

  def initialize_reporting_dashboard
    self.reporting_dashboard = ReportingDashboard.new
  end

  def deactivate_organization_and_intervention_admins
    organization_admins.each do |organization_admin|
      organization_admin.deactivate!
      organization_admins.delete(organization_admin)
    end

    e_intervention_admins.delete_all
  end

  def update_interventions_from_deleted_organization
    Intervention.where(organization_id: id).find_each { |intervention| intervention.update!(organization_id: nil, from_deleted_organization: true) }
  end

  def really_destroy_all_children
    health_systems.with_deleted.each(&:really_destroy!)
  end
end
