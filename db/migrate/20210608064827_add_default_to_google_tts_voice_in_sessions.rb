# frozen_string_literal: true

class AddDefaultToGoogleTtsVoiceInSessions < ActiveRecord::Migration[6.0]
  def change
    change_column_default :sessions, :google_tts_voice_id, from: nil, to: 43
  end
end
