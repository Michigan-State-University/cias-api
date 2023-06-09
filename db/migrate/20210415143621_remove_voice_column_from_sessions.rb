# frozen_string_literal: true

class RemoveVoiceColumnFromSessions < ActiveRecord::Migration[6.0]
  def change
    remove_column :sessions, :language_code, :string
    remove_column :sessions, :voice_name, :string

    add_reference :sessions, :google_tts_voice, null: true, foreign_key: true
  end
end
