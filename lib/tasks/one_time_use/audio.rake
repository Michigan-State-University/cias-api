# frozen_string_literal: true

namespace :audio do
  desc 'Recreate audios to have correct usage counters and remove outdated files'
  task recreate: :environment do
    UserSession.where.not(name_audio: [nil]).update_all(name_audio_id: nil)
    Audio.delete_all
    Question.find_each do |question|
      question.duplicated = true
      question.execute_narrator
      question.duplicated = false
    end
  end
end
