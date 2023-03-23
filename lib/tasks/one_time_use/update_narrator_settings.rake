# frozen_string_literal: true

namespace :one_time_use do
  desc 'Update narrator settings - add a new filed to all exising question (skip TLFB questions)'
  task update_narrator_settings: :environment do
    ActiveRecord::Base.transaction do
      scope = Question.all.where.not(type: %w[Question::TlfbConfig Question::TlfbEvents Question::TlfbQuestion])
      question_count = scope.size

      scope.each_with_index do |question, index|
        question.narrator['settings']['extra_space_for_narrator'] = false
        question.save!
        p "question #{index + 1}/#{question_count}"
      end

      p 'DONE!'
    end
  end
end
