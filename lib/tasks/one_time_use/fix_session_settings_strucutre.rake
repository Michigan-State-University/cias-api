# frozen_string_literal: true

namespace :sessions do
  desc 'Fix settings for sessions'
  task settings_fix: :environment do
    Session.all.each do |session|
      next unless session.settings['formula'].nil? || session.settings['narrator'].nil?

      session.settings['formula'] = false if session.settings['formula'].nil?
      session.settings['narrator'] = { 'voice' => true, 'animation' => true } if session.settings['narrator'].nil?
      session.save!
    end
  end
end
