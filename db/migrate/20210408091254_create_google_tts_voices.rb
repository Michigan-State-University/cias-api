# frozen_string_literal: true

class CreateGoogleTtsVoices < ActiveRecord::Migration[6.0]
  def change
    create_table :google_tts_voices do |t|
      t.integer :google_tts_language_id, index: true, foreign_key: true
      t.string :voice_label
      t.string :voice_type
      t.string :language_code

      t.timestamps
    end
  end
  Rake::Task['google_tts_languages:fetch'].invoke
end
