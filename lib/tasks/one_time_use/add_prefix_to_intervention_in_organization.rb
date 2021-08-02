# frozen_string_literal: true

namespace :one_time_use do
  desc 'Add prefix [Reporting] to Intervention belongs to some organization'
  task add_prefix_to_intervention_in_organization: :environment do
    Intervention.with_any_organization.find_each do |intervention|
      intervention.update!(name: "[Reporting] #{intervention.name}") if intervention.name.exclude?('[Reporting]')
    end
  end
end
