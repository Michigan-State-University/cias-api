class CreateCatMhGoogleTtsVoices < ActiveRecord::Migration[6.0]
  def change
    create_table :cat_mh_google_tts_voices do |t|
      t.integer :google_tts_voice_id
      t.integer :cat_mh_language_id
      t.timestamps
    end
    add_foreign_key :cat_mh_google_tts_voices, :google_tts_voices, column: :google_tts_voice_id
    add_foreign_key :cat_mh_google_tts_voices, :cat_mh_languages, column: :cat_mh_language_id
  end
end
