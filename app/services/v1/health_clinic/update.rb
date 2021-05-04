# frozen_string_literal: true

class V1::HealthClinic::Update
  def self.call(health_clinic, health_clinic_params)
    new(health_clinic, health_clinic_params).call
  end

  def initialize(health_clinic, health_clinic_params)
    @health_clinic = health_clinic
    @health_clinic_params = health_clinic_params
  end

  def call
    health_clinic.update!(name: health_clinic_params[:name]) if name_changed?

    health_clinic.reload
  end

  private

  attr_accessor :health_clinic
  attr_reader :health_clinic_params

  def name_changed?
    return false if health_clinic_params[:name].blank?

    health_clinic.name != health_clinic_params[:name]
  end
end
