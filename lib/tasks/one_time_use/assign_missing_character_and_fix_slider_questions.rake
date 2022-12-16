# frozen_string_literal: true

namespace :one_time_use do
  desc 'Fix missing character and slider questions'
  task assign_missing_character_and_fix_slider_questions: :environment do
    Question.all.find_each do |question|
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
      question.save!
    end
  end
end
