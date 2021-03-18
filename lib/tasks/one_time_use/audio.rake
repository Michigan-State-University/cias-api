# frozen_string_literal: true

namespace :audio do
  desc 'Recreate audios to have correct usage counters and remove outdated files'
  task recreate: :environment do
    Audio.delete_all
    Question.all.each do |question|
      question.duplicated = true
      question.execute_narrator
      question.duplicated = false
    end
  end
end
