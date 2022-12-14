# frozen_string_literal: true

namespace :one_time_use do
  desc 'Assign default ranges to all slider questions without already set value'
  task assign_ranges_to_slider_questions: :environment do
    question_count = Question::Slider.count
    Question::Slider.all.find_each.with_index(1) do |question, index|
      payload = question.body['data'].first['payload']
      unless payload.key?('range_start') && payload.key?('range_end')
        payload['range_start'] = 0
        payload['range_end'] = 100
        question.save!
      end
      puts "#{index}/#{question_count} slider questions checked."
    end
  end
end
