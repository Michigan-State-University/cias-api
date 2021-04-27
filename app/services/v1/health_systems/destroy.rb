# frozen_string_literal: true

class V1::HealthSystems::Destroy
  def self.call(health_system)
    new(health_system).call
  end

  def initialize(health_system)
    @health_system = health_system
    @health_system_admins = health_system.health_system_admins
  end

  def call
    ActiveRecord::Base.transaction do
      health_system_admins.each do |health_system_admin|
        health_system_admin.deactivate!
        health_system_admins.delete(health_system_admin)
      end

      health_system.destroy!
    end
  end

  private

  attr_reader :health_system, :health_system_admins
end
