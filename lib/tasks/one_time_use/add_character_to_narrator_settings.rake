# frozen_string_literal: true

namespace :questions do
  desc 'Set default character for exited questions'
  task character_default_setting: :environment do
    question_count = Question.count
    Question.all.each_with_index do |question, index|
      question.narrator['settings'] = question.narrator['settings'].merge({'character' => 'peedy'})
      question.save
      p "Done #{index + 1}/#{question_count} questions"
    end
    p 'Task done'
  end
end
