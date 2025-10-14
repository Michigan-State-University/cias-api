# frozen_string_literal: true

namespace :one_time_use do
  desc 'Set default google tts language for some google language'
  task assign_default_google_tts_to_google_language: :environment do
    english = AuxiliaryGoogleLanguage.find_by(language_code: 'en')
    spanish = AuxiliaryGoogleLanguage.find_by(language_code: 'es')

    english.update!(google_tts_language:  AuxiliaryGoogleTtsLanguage.find_by(language_name: 'English (United States)'))
    spanish.update!(google_tts_language: AuxiliaryGoogleTtsLanguage.find_by(language_name: 'Spanish (Spain)'))
  end

  class AuxiliaryGoogleLanguage < ActiveRecord::Base
    self.table_name = 'google_languages'

    belongs_to :google_tts_language, foreign_key: :google_tts_language_id, class_name: 'AuxiliaryGoogleTtsLanguage'
  end

  class AuxiliaryGoogleTtsLanguage < ActiveRecord::Base
    self.table_name = 'google_tts_languages'

    has_many :google_languages, dependent: :nullify, foreign_key: :google_tts_language_id, class_name: 'AuxiliaryGoogleLanguage'
  end
end
