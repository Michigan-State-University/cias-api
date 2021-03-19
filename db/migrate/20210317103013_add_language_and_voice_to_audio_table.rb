# frozen_string_literal: true

class AddLanguageAndVoiceToAudioTable < ActiveRecord::Migration[6.0]
  def up
    change_table :audios, bulk: true do |t|
      t.string :language
      t.string :voice_type
      t.remove_index :sha256
      t.index %i[sha256 language voice_type], unique: true
    end
  end

  def down
    change_table :audios, bulk: true do |t|
      t.remove :language
      t.remove :voice_type
      t.remove_index %i[sha256 language voice_type]
      t.index :sha256, unique: true
    end
  end
end
