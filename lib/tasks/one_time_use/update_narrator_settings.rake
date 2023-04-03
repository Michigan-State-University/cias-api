# frozen_string_literal: true

namespace :one_time_use do
  desc 'Update narrator settings - add a new filed to all exising question (skip TLFB questions)'
  task update_narrator_settings: :environment do
    ActiveRecord::Base.transaction do
      scope = Question.all.where.not(type: %w[Question::TlfbConfig Question::TlfbEvents Question::TlfbQuestion])
      question_count = scope.size
      current_question = 0

      scope.find_each do |question|
        question.narrator['settings']['extra_space_for_narrator'] = false
        question.save!
        p "question #{current_question + 1}/#{question_count}"
        current_question = current_question + 1
      end

      p 'DONE!'
    end
  end
end
