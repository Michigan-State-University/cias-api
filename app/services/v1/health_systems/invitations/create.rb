# frozen_string_literal: true

class V1::HealthSystems::Invitations::Create
  def self.call(health_system, user)
    new(health_system, user).call
  end

  def initialize(health_system, user)
    @health_system = health_system
    @user = user
  end

  def call
    return if invitation_already_exists?
    return unless user.confirmed?

    invitation = HealthSystemInvitation.create!(
      user: user,
      health_system: health_system
    )

    OrganizableMailer.invite_user(
      invitation_token: invitation.invitation_token,
      email: user.email,
      organizable: health_system,
      organizable_type: 'Health System'
    ).deliver_later
  end

  private

  attr_reader :health_system, :user

  def invitation_already_exists?
    HealthSystemInvitation.not_accepted.exists?(user_id: user.id, health_system_id: health_system.id)
  end
end
