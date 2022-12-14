# frozen_string_literal: true

namespace :one_time_use do
  desc 'Assigns Peedy as a character for questions with missing character in narrator settings'
  task assign_missing_character_in_question_narrator_settings: :environment do
    Question.all.find_each do |question|
      unless question.narrator['settings'].key?('character')
        question.narrator['settings']['character'] = 'peedy'
        question.save!
      end
    end
  end
end
