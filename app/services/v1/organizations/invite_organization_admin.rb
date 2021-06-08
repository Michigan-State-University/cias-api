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
    return if user_is_not_new_in_the_system?

    new_user = User.invite!(email: email, roles: ['organization_admin'], organizable_id: organization.id, organizable_type: 'Organization')
    organization.organization_admins << new_user
  end

  private

  attr_reader :organization, :email

  def user_is_not_new_in_the_system?
    user.present?
  end

  def user
    @user ||= User.find_by(email: email)
  end
end
