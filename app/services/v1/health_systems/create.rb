# frozen_string_literal: true

class V1::HealthSystems::Create
  def self.call(health_system_params)
    new(health_system_params).call
  end

  def initialize(health_system_params)
    @health_system_params = health_system_params
  end

  def call
    ActiveRecord::Base.transaction do
      health_system = HealthSystem.create!(
        name: health_system_params[:name],
        organization_id: health_system_params[:organization_id]
      )

      V1::HealthSystems::ChangeHealthSystemAdmins.call(
        health_system,
        health_system_params[:health_system_admins_to_add],
        nil
      )

      health_system
    end
  end

  private

  attr_reader :health_system_params
end
