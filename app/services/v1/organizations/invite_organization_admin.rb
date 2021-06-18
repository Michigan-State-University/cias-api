# frozen_string_literal: true

class V1::Organizations::InviteOrganizationAdmin
  def self.call(organization, email)
    new(organization, email).call
  end

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
      V1::Organizations::Invitations::Create.call(organization, user)
    end
  end

  private

  attr_reader :organization, :email

  def already_in_any_organization?
    user&.organizable.present?
  end

  def user_is_not_organization_admin?
    user&.roles&.exclude?('organization_admin')
  end

  def active_user?
    user&.active?
  end

  def user
    @user ||= User.find_by(email: email)
  end
end
