# frozen_string_literal: true

class Ability::OrganizationAdmin < Ability::Base
  def definition
    super
    organization_admin if role?(class_name)
  end

  private

  def organization_admin
    can :read, Organization, organization_admins: { id: user.id }
    can :read, ReportingDashboard, organization: { organization_admins: { id: user.id } }
    can :confirm_organization_membership, OrganizationInvitation, user_id: user.id
    can :read, HealthSystem, organization: { organization_admins: { id: user.id } }
    can :read, HealthClinic
  end
end
