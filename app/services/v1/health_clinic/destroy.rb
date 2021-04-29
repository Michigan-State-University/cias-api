# frozen_string_literal: true

class V1::HealthClinic::Destroy
  def self.call(health_clinic)
    new(health_clinic).call
  end

  def initialize(health_clinic)
    @health_clinic = health_clinic
  end

  def call
    health_clinic.destroy!
  end

  private

  attr_accessor :health_clinic
end
