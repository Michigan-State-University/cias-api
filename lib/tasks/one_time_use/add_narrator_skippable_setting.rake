# frozen_string_literal: true

namespace :questions do
  desc 'Enable sms notifications for all users'
  task add_narrator_skippable_setting: :environment do
    question_count = Question.count
    Question.all.each_with_index do |question, index|
      question.settings['narratorSkippable'] = false
      question.save!
      p "Done #{index}/#{question_count} questions"
    end
    p 'Task done'
  end
end
