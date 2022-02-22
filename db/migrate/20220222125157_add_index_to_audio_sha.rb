class AddIndexToAudioSha < ActiveRecord::Migration[6.1]
  def change
    add_index :audios, :sha256, unique: true
  end
end
