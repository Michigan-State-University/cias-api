# frozen_string_literal: true

class FetchGoogleTtsInMigration < ActiveRecord::Migration[6.0]
  Rake::Task['google_tts_languages:fetch'].invoke
end
