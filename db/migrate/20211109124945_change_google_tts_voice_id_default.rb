# frozen_string_literal: true

class ChangeGoogleTtsVoiceIdDefault < ActiveRecord::Migration[6.0]
  def change
    change_column_default :sessions, :google_tts_voice_id, nil
  end
end
