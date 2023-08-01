# frozen_string_literal: true

class V1::BaseOrganizationInvitation
  def self.call(organizable, email)
    new(organizable, email).call
  end

  def initialize(_organizable, _email)
    raise NotImplementedError, "Including class did not implement #{__method__} method"
  end

  protected

  def already_in_any_organization?
    user&.organizable.present?
  end

  def user_is_not_health_system_admin?
    user&.roles&.exclude?('health_system_admin')
  end

  def active_user?
    user&.active?
  end

  def user
    @user ||= User.find_by(email: email)
  end
end
