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
    return if user_is_not_e_intervention_admin_or_researcher?

    if user.blank?
      new_user = User.invite!(email: email, roles: ['e_intervention_admin'], organizable_id: organization.id, organizable_type: 'Organization', active: false)
      organization.e_intervention_admins << new_user
    else
      set_researcher_as_e_intervention_admin
      organization.e_intervention_admin_organizations << EInterventionAdminOrganization.new(user: user, organization: organization)
      V1::Organizations::Invitations::Create.call(organization, user)
    end
  end

  private

  attr_reader :organization, :email

  def already_in_the_organization?
    organization.e_intervention_admins.exists?(email: email)
  end

  def user_is_not_e_intervention_admin_or_researcher?
    user&.roles&.exclude?('researcher') && user&.roles&.exclude?('e_intervention_admin')
  end

  def set_researcher_as_e_intervention_admin
    user.roles = ['e_intervention_admin'] if user.roles.include?('researcher')
  end

  def user
    @user ||= User.find_by(email: email)
  end
end
