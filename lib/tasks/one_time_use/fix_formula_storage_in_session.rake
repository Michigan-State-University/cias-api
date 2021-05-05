# frozen_string_literal: true

namespace :session do
  desc 'Fix storage target in formula for questions'
  task target_fix: :environment do
    Session.all.each do |session|
      next unless session['formula']['patterns'].any?

      session['formula']['patterns'].each do |pattern|
        pattern['target']['probability'] = 100.to_s
        target = pattern['target']
        pattern['target'] = [target]
      end

      session.save!
    end
  end
end
