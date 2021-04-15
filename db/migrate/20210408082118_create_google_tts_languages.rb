# frozen_string_literal: true

class CreateGoogleTtsLanguages < ActiveRecord::Migration[6.0]
  def change
    create_table :google_tts_languages do |t|
      t.string :language_name, null: false
      t.timestamps
    end
  end
end
