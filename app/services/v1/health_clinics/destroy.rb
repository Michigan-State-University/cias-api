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
        health_clinic_admin.deactivate!
        health_clinic_admins.delete(health_clinic_admin)
      end

      health_clinic.destroy!
    end
  end

  private

  attr_accessor :health_clinic, :health_clinic_admins
end
