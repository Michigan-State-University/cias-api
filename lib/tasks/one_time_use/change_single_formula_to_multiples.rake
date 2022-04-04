# frozen_string_literal: true

namespace :one_time_use do
  desc 'Changes the single formula in questions to multiples'
  task change_single_formula_to_multiples: :environment do
    Question.all.find_each do |question|
      question.update!(formulas: [question.formulas])
    end
    Session.all.find_each do |session|
      session.update!(formulas: [session.formulas])
    end
  end
end
