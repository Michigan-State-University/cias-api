# frozen_string_literal: true

class V1::Organizations::ChangeOrganizationAdmins
  def self.call(organization, organization_admins_to_add, organization_admins_to_remove)
    new(organization, organization_admins_to_add, organization_admins_to_remove).call
  end

  def initialize(organization, organization_admins_to_add, organization_admins_to_remove)
    @organization = organization
    @organization_admins_to_add = organization_admins_to_add
    @organization_admins_to_remove = organization_admins_to_remove
  end

  def call
    ActiveRecord::Base.transaction do
      add_organization_admins
      remove_organization_admins
    end
  end

  private

  attr_reader :organization, :organization_admins_to_add, :organization_admins_to_remove

  def add_organization_admins
    return unless organization_admins_to_add

    organization_admins_to_add.each do |organization_admin_id|
      next if admin_in_organization?(organization_admin_id)

      organization_admin_to_add = organization_admin(organization_admin_id)
      organization_admin_to_add.activate!
      organization_admin_to_add.organizable = organization
      organization_admin_to_add.save!

      OrganizationInvitation.not_accepted.where(user_id: organization_admin_id).destroy_all
    end
  end

  def remove_organization_admins
    return unless organization_admins_to_remove

    organization_admins_to_remove.each do |organization_admin_id|
      next unless admin_in_organization?(organization_admin_id)

      organization_admin_to_remove = organization_admin(organization_admin_id)
      organization_admin_to_remove.deactivate!
      organization_admin_to_remove.organizable = nil
      organization_admin_to_remove.save!
    end
  end

  def admin_in_organization?(organization_admin_id)
    return true if organization_admin_id.blank?

    current_organization_admins.where(id: organization_admin_id).any?
  end

  def organization_admin(organization_admin_id)
    @organization_admin ||= User.limit_to_roles(%w[organization_admin])
                            .find(organization_admin_id)
  end

  def current_organization_admins
    @current_organization_admins ||= organization.organization_admins
  end
end
