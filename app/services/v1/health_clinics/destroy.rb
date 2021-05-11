# frozen_string_literal: true

class V1::HealthClinics::Destroy
  def self.call(health_clinic)
    new(health_clinic).call
  end

  def initialize(health_clinic)
    @health_clinic = health_clinic
    @health_clinic_admins = health_clinic.health_clinic_admins
  end

  def call
    ActiveRecord::Base.transaction do
      health_clinic_admins.each do |health_clinic_admin|
        health_clinic_admin.user_health_clinics.find_by(health_clinic_id: health_clinic.id).destroy!
        health_clinic_admin.deactivate! if no_more_health_clinics?(health_clinic_admin)
        health_clinic_admins.delete(health_clinic_admin)
      end

      health_clinic.destroy!
    end
  end

  private

  attr_accessor :health_clinic, :health_clinic_admins

  def no_more_health_clinics?(health_clinic_admin)
    health_clinic_admin.user_health_clinics.empty?
  end
end
