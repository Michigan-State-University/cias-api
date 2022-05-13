# frozen_string_literal: true

namespace :one_time_use do
  desc 'Set default google tts language for some google language'
  task assign_default_google_tts_to_google_language: :environment do
    english = GoogleLanguage.find_by(language_code: 'en')
    spanish = GoogleLanguage.find_by(language_code: 'es')

    english.update!(google_tts_language:  GoogleTtsLanguage.find_by(language_name: 'English (United States)'))
    spanish.update!(google_tts_language: GoogleTtsLanguage.find_by(language_name: 'Spanish (Spain)'))
  end
end
