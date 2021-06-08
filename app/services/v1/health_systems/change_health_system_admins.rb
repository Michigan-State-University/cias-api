# frozen_string_literal: true

class V1::HealthSystems::ChangeHealthSystemAdmins
  def self.call(health_system, health_system_admins_to_add, health_system_admins_to_remove)
    new(health_system, health_system_admins_to_add, health_system_admins_to_remove).call
  end

  def initialize(health_system, health_system_admins_to_add, health_system_admins_to_remove)
    @health_system = health_system
    @health_system_admins_to_add = health_system_admins_to_add
    @health_system_admins_to_remove = health_system_admins_to_remove
  end

  def call
    ActiveRecord::Base.transaction do
      add_health_system_admins
      remove_health_system_admins
    end
  end

  private

  attr_reader :health_system, :health_system_admins_to_add, :health_system_admins_to_remove

  def add_health_system_admins
    return unless health_system_admins_to_add

    health_system_admins_to_add.each do |health_system_admin_id|
      next if admin_in_health_system?(health_system_admin_id)

      health_system_admin_to_add = health_system_admin(health_system_admin_id)
      health_system_admin_to_add.activate!
      health_system_admin_to_add.organizable = health_system
      health_system_admin_to_add.save!

      HealthSystemInvitation.not_accepted.where(user_id: health_system_admin_id).destroy_all
    end
  end

  def remove_health_system_admins
    return unless health_system_admins_to_remove

    health_system_admins_to_remove.each do |health_system_admin_id|
      next unless admin_in_health_system?(health_system_admin_id)

      health_system_admin_to_remove = health_system_admin(health_system_admin_id)
      health_system_admin_to_remove.deactivate!
      health_system_admin_to_remove.organizable = nil
      health_system_admin_to_remove.save!
    end
  end

  def admin_in_health_system?(health_system_admin_id)
    return true if health_system_admin_id.blank?

    current_health_system_admins.where(id: health_system_admin_id).any?
  end

  def health_system_admin(health_system_admin_id)
    User.limit_to_roles(%w[health_system_admin]).find(health_system_admin_id)
  end

  def current_health_system_admins
    @current_health_system_admins ||= health_system.health_system_admins
  end
end
