# frozen_string_literal: true

class V1::HealthSystems::Destroy
  def self.call(health_system)
    new(health_system).call
  end

  def initialize(health_system)
    @health_system = health_system
  end

  def call
    ActiveRecord::Base.transaction do
      cancel_user_invitations(health_system)
      health_system.destroy!
    end
  end

  private

  attr_reader :health_system

  def cancel_user_invitations(health_system)
    organizable_ids = health_system.health_clinics.ids + [health_system.id]
    User.where(organizable_id: organizable_ids, active: false, confirmed_at: nil).delete_all
  end
end
