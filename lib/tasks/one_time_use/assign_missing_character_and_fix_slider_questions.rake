# frozen_string_literal: true

namespace :one_time_use do
  desc 'Fix missing character and slider questions'
  task assign_missing_character_and_fix_slider_questions: :environment do
    question_count = Question.count
    Question.find_each.with_index do |question, index|
      if question.narrator['settings'].key?('character') or not question.is_a?(Question::Slider)
        p "Skipping migration for #{index}/#{question_count}"
        next
      end

      unless question.narrator['settings'].key?('character')
        question.narrator['settings']['character'] = 'peedy'
      end
      if question.is_a?(Question::Slider)
        payload = question.body['data'].first['payload']
        unless payload.key?('range_start') && payload.key?('range_end')
          payload['range_start'] = 0
          payload['range_end'] = 100
        end
      end
      p "Migrating question #{index}/#{question_count}"
      question.save!
    end
  end
end
