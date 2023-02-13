# frozen_string_literal: true

class V1::Organizations::Destroy
  def self.call(organization)
    new(organization).call
  end

  def initialize(organization)
    @organization = organization
  end

  def call
    ActiveRecord::Base.transaction do
      cancel_user_invitations(organization)
      e_intervention_admins = organization.e_intervention_admins.where(organizable_id: organization.id)
      e_intervention_admins.each { |user| user.update!(organizable: nil) }
      organization.destroy!
    end
  end

  private

  attr_reader :organization

  def cancel_user_invitations(organization)
    organizable_ids = organization.health_clinics.ids + organization.health_systems.ids + [organization.id]
    User.where(organizable_id: organizable_ids, active: false, confirmed_at: nil).delete_all
  end
end
