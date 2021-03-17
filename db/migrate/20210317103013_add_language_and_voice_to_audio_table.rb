class AddLanguageAndVoiceToAudioTable < ActiveRecord::Migration[6.0]
  def up
    change_table :audios, bulk: true do |t|
      t.string :language
      t.string :voice_type
    end
  end

  def down
    change_table :audios, bulk: true do |t|
      t.remove :language
      t.remove :voice_type
    end
  end
end
