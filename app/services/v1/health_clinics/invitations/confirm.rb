# frozen_string_literal: true

class V1::HealthClinics::Invitations::Confirm
  def self.call(health_clinic_invitation)
    new(health_clinic_invitation).call
  end

  def initialize(health_clinic_invitation)
    @health_clinic = health_clinic_invitation.health_clinic
    @user = health_clinic_invitation.user
    @health_clinic_invitation = health_clinic_invitation
  end

  def call
    ActiveRecord::Base.transaction do
      user.activate!

      health_clinic_invitation.update!(
        accepted_at: Time.current,
        invitation_token: nil
      )
    end
  end

  private

  attr_reader :health_clinic, :user, :health_clinic_invitation
end
