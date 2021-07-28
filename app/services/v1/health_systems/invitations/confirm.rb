# frozen_string_literal: true

class V1::HealthSystems::Invitations::Confirm
  prepend Database::Transactional

  def self.call(health_system_invitation)
    new(health_system_invitation).call
  end

  def initialize(health_system_invitation)
    @health_system = health_system_invitation.health_system
    @user = health_system_invitation.user
    @health_system_invitation = health_system_invitation
  end

  def call
    user.update!(organizable: health_system)
    user.activate!

    health_system_invitation.update!(
      accepted_at: Time.current,
      invitation_token: nil
    )
  end

  private

  attr_reader :health_system, :user, :health_system_invitation
end
