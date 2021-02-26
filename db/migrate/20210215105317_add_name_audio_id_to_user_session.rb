# frozen_string_literal: true

class AddNameAudioIdToUserSession < ActiveRecord::Migration[6.0]
  def change
    add_reference(:user_sessions, :name_audio, foreign_key: { to_table: :audios }, type: :uuid)
  end
end
