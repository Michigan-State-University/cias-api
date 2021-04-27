# frozen_string_literal: true

class V1::HealthSystems::Invitations::Confirm
  def self.call(health_system_invitation)
    new(health_system_invitation).call
  end

  def initialize(health_system_invitation)
    @health_system = health_system_invitation.health_system
    @user = health_system_invitation.user
    @health_system_invitation = health_system_invitation
  end

  def call
    ActiveRecord::Base.transaction do
      user.update!(organizable: health_system)
      health_system.health_system_admins << user

      health_system_invitation.update!(
        accepted_at: Time.current,
        invitation_token: nil
      )
    end
  end

  private

  attr_reader :health_system, :user, :health_system_invitation
end
