# frozen_string_literal: true

class V1::HealthClinics::Invitations::Create
  def self.call(health_clinic, user)
    new(health_clinic, user).call
  end

  def initialize(health_clinic, user)
    @health_clinic = health_clinic
    @user = user
  end

  def call
    return if invitation_already_exists?
    return unless user.confirmed?

    invitation = HealthClinicInvitation.create!(
      user: user,
      health_clinic: health_clinic
    )

    OrganizableMailer.invite_user(
      invitation_token: invitation.invitation_token,
      email: user.email,
      organizable: health_clinic,
      organizable_type: 'Health Clinic'
    ).deliver_later
  end

  private

  attr_reader :health_clinic, :user

  def invitation_already_exists?
    HealthClinicInvitation.not_accepted.exists?(user_id: user.id, health_clinic_id: health_clinic.id)
  end
end
