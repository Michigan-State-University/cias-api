# frozen_string_literal: true

class RakeToAssignGoogleTtsLanguageToGoogleLanguage < ActiveRecord::Migration[6.0]
  def change
    Rake::Task['one_time_use:assign_default_google_tts_to_google_language'].invoke
  end
end
