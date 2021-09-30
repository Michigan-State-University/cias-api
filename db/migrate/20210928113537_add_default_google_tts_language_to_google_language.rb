# frozen_string_literal: true

class AddDefaultGoogleTtsLanguageToGoogleLanguage < ActiveRecord::Migration[6.0]
  def change
    add_reference :google_languages, :google_tts_language, null: true, foreign_key: true
  end

  Rake::Task['one_time_use:assign_default_google_tts_to_google_language'].invoke
end
