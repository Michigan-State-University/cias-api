# frozen_string_literal: true

namespace :one_time_use do
  desc 'Destroy all health systems with invalid relationship'
  task really_destroy_all_invalid_health_systems: :environment do
    HealthSystem.only_deleted.each do |health_system|
      health_system.really_destroy! if health_system.organization.blank?
    end
    p 'removed all health systems without organization'
  end
end
