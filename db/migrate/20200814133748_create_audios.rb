# frozen_string_literal: true

class CreateAudios < ActiveRecord::Migration[6.0]
  def change
    create_table :audios, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.string :sha256, null: false
      t.integer :usage_counter, default: 1

      t.index :sha256, unique: true

      t.timestamps
    end
  end
end
