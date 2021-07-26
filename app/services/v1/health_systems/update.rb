# frozen_string_literal: true

class V1::HealthSystems::Update
  def self.call(health_system, health_system_params)
    new(health_system, health_system_params).call
  end

  def initialize(health_system, health_system_params)
    @health_system = health_system
    @health_system_params = health_system_params
  end

  def call
    ActiveRecord::Base.transaction do
      health_system.update!(name: health_system_params[:name]) if name_changed?
      health_system.reload
    end
  end

  private

  attr_reader :health_system, :health_system_params

  def new_health_system_admin
    @new_health_system_admin ||= User.limit_to_roles(%w[health_system_admin])
                                    .find(health_system_params[:health_system_admin_id])
  end

  def name_changed?
    return false if health_system_params[:name].blank?

    health_system.name != health_system_params[:name]
  end
end
