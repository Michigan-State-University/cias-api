# frozen_string_literal: true

class V1::Organizations::Destroy
  def self.call(organization)
    new(organization).call
  end

  def initialize(organization)
    @organization = organization
    @organization_admins = organization.organization_admins
    @e_intervention_admins = organization.e_intervention_admins
  end

  def call
    ActiveRecord::Base.transaction do
      organization_admins.each do |organization_admin|
        organization_admin.deactivate!
        organization.organization_admins.delete(organization_admin)
      end

      e_intervention_admins.each do |intervention_admin|
        organization.e_intervention_admins.delete(intervention_admin)
      end

      organization.destroy!
    end
  end

  private

  attr_reader :organization, :organization_admins, :e_intervention_admins
end
