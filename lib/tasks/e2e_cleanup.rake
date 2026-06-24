# frozen_string_literal: true

namespace :e2e do
  desc 'Delete all interventions created by e2e users'
  task cleanup_interventions: :environment do
    puts 'Starting E2E interventions cleanup...'

    E2e::CleanupService.call
  end
end
