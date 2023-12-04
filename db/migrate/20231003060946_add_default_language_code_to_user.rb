class AddDefaultLanguageCodeToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :language_code, :string, default: 'en'
  end
end
