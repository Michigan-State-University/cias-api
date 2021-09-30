# frozen_string_literal: true

class AddDefaultGoogleTtsLanguageToGoogleLanguage < ActiveRecord::Migration[6.0]
  def change
    add_reference :google_languages, :google_tts_language, null: true, foreign_key: true
  end
end
