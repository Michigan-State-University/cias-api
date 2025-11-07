# frozen_string_literal: true

class V1::Organizations::InviteEInterventionAdmin
  def self.call(organization, email)
    new(organization, email).call
  end

  def initialize(organization, email)
    @organization = organization
    @email = email
  end

  def call
    return if already_in_the_organization?
    return if user_is_not_researcher?

    if user.blank?
      new_user = User.invite!(email: email, roles: %w[researcher e_intervention_admin], organizable_id: organization.id, organizable_type: 'Organization',
                              active: false)
      organization.e_intervention_admins << new_user
    else
      organization.e_intervention_admin_organizations << EInterventionAdminOrganization.new(user: user, organization: organization)
      V1::Organizations::Invitations::Create.call(organization, user)
    end
  end

  private

  attr_reader :organization, :email

  def already_in_the_organization?
    organization.e_intervention_admins.exists?(email: email)
  end

  def user_is_not_researcher?
    user&.roles&.exclude?('researcher')
  end

  def user
    return @user if defined?(@user)

    @user = User.find_by(email: email)
  end
end
