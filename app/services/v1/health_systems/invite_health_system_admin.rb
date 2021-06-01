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
    return if user_is_not_new_in_the_system?

    new_user = User.invite!(email: email, roles: ['health_system_admin'], organizable_id: health_system.id, organizable_type: 'HealthSystem')
    health_system.health_system_admins << new_user
  end

  private

  attr_reader :health_system, :email

  def user_is_not_new_in_the_system?
    user.present?
  end

  def user
    @user ||= User.find_by(email: email)
  end
end
