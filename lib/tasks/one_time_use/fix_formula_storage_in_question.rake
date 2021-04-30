# frozen_string_literal: true

namespace :questions do
  desc 'Fix storage target in formula for questions'
  task target_fix: :environment do
    Question.all.each do |question|
      next unless question['formula']['patterns'].any?

      question['formula']['patterns'].each do |pattern|
        pattern['target']['probability'] = 100.to_s
        target = pattern['target']
        pattern['target'] = [target]
      end

      question.save!
    end
  end
end
