class AddCatMhLanguagesToSessions < ActiveRecord::Migration[6.0]
  def change
    add_reference :sessions, :cat_mh_language, null: true, foreign_key: true
  end
end
