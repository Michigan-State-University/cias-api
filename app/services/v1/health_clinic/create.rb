# frozen_string_literal: true

class V1::HealthClinic::Create
  def self.call(health_clinic_params)
    new(health_clinic_params).call
  end

  def initialize(health_clinic_params)
    @health_clinic_params = health_clinic_params
  end

  def call
    HealthClinic.create!(name: health_clinic_params[:name], health_system_id: health_clinic_params[:health_system_id])
  end

  private

  attr_reader :health_clinic_params
end
