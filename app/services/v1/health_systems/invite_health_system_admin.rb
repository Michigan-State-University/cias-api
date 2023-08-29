# frozen_string_literal: true

class V1::HealthSystems::InviteHealthSystemAdmin < V1::BaseOrganizationInvitation
  def initialize(health_system, email)
    @health_system = health_system
    @email = email
  end

  def call
    return if already_in_any_organization?
    return if user_is_not_health_system_admin?
    return if active_user?

    if user.blank?
      new_user = User.invite!(email: email, roles: ['health_system_admin'], organizable_id: health_system.id, organizable_type: 'HealthSystem', active: false)
      health_system.health_system_admins << new_user
    else
      health_system.health_system_admins << user
      V1::Organizations::Invitations::Create.call(health_system, user)
    end
  end

  private

  attr_reader :health_system, :email

  def user_is_not_health_system_admin?
    user&.roles&.exclude?('health_system_admin')
  end
end
