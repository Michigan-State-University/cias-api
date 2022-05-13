# frozen_string_literal: true

class V1::HealthSystems::Create
  def self.call(health_system_params)
    new(health_system_params).call
  end

  def initialize(health_system_params)
    @health_system_params = health_system_params
  end

  def call
    HealthSystem.create!(
      name: health_system_params[:name],
      organization_id: health_system_params[:organization_id]
    )
  end

  private

  attr_reader :health_system_params
end
