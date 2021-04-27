# frozen_string_literal: true

class V1::HealthSystems::InviteHealthSystemAdmin
  def self.call(health_system, email)
    new(health_system, email).call
  end

  def initialize(health_system, email)
    @health_system = health_system
    @email = email
  end

  def call
    return if already_in_the_health_system?
    return if user_is_not_health_system_admin?

    if user.blank?
      new_user = User.invite!(email: email, roles: ['health_system_admin'], organizable_id: health_system.id)
      health_system.health_system_admins << new_user
    else
      V1::HealthSystems::Invitations::Create.call(health_system, user)
    end
  end

  private

  attr_reader :health_system, :email

  def already_in_the_health_system?
    health_system.health_system_admins.exists?(email: email)
  end

  def user_is_not_health_system_admin?
    user&.roles&.exclude?('health_system_admin')
  end

  def user
    @user ||= User.find_by(email: email)
  end
end
