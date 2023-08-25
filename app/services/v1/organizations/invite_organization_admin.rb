# frozen_string_literal: true

class V1::Organizations::InviteOrganizationAdmin < V1::BaseOrganizationInvitation
  def initialize(organization, email)
    @organization = organization
    @email = email
  end

  def call
    return if already_in_any_organization?
    return if user_is_not_organization_admin?
    return if active_user?

    if user.blank?
      new_user = User.invite!(email: email, roles: ['organization_admin'], organizable_id: organization.id, organizable_type: 'Organization', active: false)
      organization.organization_admins << new_user
    else
      organization.organization_admins << user
      V1::Organizations::Invitations::Create.call(organization, user)
    end
  end

  private

  attr_reader :organization, :email

  def user_is_not_organization_admin?
    user&.roles&.exclude?('organization_admin')
  end
end
