# frozen_string_literal: true

namespace :audio do
  desc 'Clean audio blobs'
  task clean: :environment do
    Audio.where(usage_counter: 0).find_each do |audio|
      audio.mp3.purge
    end
  end
end
