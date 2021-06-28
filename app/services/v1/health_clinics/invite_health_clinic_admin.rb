# frozen_string_literal: true

class V1::HealthClinics::InviteHealthClinicAdmin
  def self.call(health_clinic, email)
    new(health_clinic, email).call
  end

  def initialize(health_clinic, email)
    @health_clinic = health_clinic
    @email = email
  end

  def call
    return if already_in_the_health_clinic?
    return if user_is_not_health_clinic_admin?

    if user.blank?
      new_user = User.invite!(email: email, roles: ['health_clinic_admin'], organizable_id: health_clinic.id, organizable_type: 'HealthClinic', active: false)
      health_clinic.user_health_clinics << UserHealthClinic.new(user: new_user, health_clinic: health_clinic)
    else
      health_clinic.user_health_clinics << user
      V1::HealthClinics::Invitations::Create.call(health_clinic, user)
    end
  end

  private

  attr_reader :health_clinic, :email

  def already_in_the_health_clinic?
    user_id = User.find_by(email: email)
    health_clinic.user_health_clinics.exists?(user_id: user_id)
  end

  def user_is_not_health_clinic_admin?
    user&.roles&.exclude?('health_clinic_admin')
  end

  def user
    @user ||= User.find_by(email: email)
  end
end
