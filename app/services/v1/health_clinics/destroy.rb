# frozen_string_literal: true

class V1::HealthClinics::Destroy
  def self.call(health_clinic)
    new(health_clinic).call
  end

  def initialize(health_clinic)
    @health_clinic = health_clinic
    @user_health_clinics = health_clinic.user_health_clinics
  end

  def call
    ActiveRecord::Base.transaction do
      user_health_clinics.each do |user_health_clinic|
        health_clinic_admin = user_health_clinic.user
        user_health_clinic.destroy!
        health_clinic_admin.deactivate! if no_more_health_clinics?(health_clinic_admin)
      end

      health_clinic.destroy!
    end
  end

  private

  attr_accessor :health_clinic, :user_health_clinics

  def no_more_health_clinics?(health_clinic_admin)
    health_clinic_admin.user_health_clinics.empty?
  end
end
