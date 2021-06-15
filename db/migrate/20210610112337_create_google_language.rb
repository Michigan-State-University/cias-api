# frozen_string_literal: true

class CreateGoogleLanguage < ActiveRecord::Migration[6.0]
  def change
    create_table :google_languages do |t|
      t.string :language_code
      t.string :language_name
      t.timestamps
    end
  end
end
