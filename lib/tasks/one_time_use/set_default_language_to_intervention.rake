# frozen_string_literal: true

namespace :one_time_use do
  desc 'Set default values of session variables'
  task set_default_language_to_intervention: :environment do
    google_language = GoogleLanguage.find_by(language_code: 'en')
    ActiveRecord::Base.transaction do
      Intervention.find_each do |intervention|
        intervention.update!(google_language: google_language)
      end
    end
  end
end
