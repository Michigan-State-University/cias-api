# frozen_string_literal: true

namespace :questions do
  desc 'Fix case in narrator_skippable'
  task fix_narrator_skippable_setting: :environment do
    question_count = Question.count
    Question.all.each_with_index do |question, index|
      prev_setting = question.settings['narratorSkippable']
      prev_setting = false if prev_setting.nil?
      question.settings['narrator_skippable'] = prev_setting
      question.settings.delete('narratorSkippable')
      question.save!
      p "Done #{index}/#{question_count} questions"
    end
    p 'Task done'
  end
end
