# frozen_string_literal: true

namespace :audio do
  desc 'Recreate audios to have correct usage counters and remove outdated files'
  task recreate: :environment do
    V1::Audio::RecreateService.call
  end
end
