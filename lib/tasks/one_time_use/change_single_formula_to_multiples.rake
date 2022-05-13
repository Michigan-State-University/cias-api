# frozen_string_literal: true

namespace :one_time_use do
  desc 'Changes the single formula in questions to multiples'
  task change_single_formula_to_multiples: :environment do
    ActiveRecord::Base.transaction do
      question_count = Question.count
      Question.all.find_each.with_index do |question, index|
        p "Updating question with formula #{index + 1}/#{question_count}"
        question.update!(formulas: [question.formulas]) unless question.formulas.is_a?(Array)
      end
      session_count = Session.count
      Session.all.find_each.with_index do |session, index|
        p "Updating session with formula #{index + 1}/#{session_count}"
        session.update!(formulas: [session.formulas]) unless session.formulas.is_a?(Array)
      end
    end
  end
end
