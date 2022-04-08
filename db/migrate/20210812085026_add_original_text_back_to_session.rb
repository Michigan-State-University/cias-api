class AddOriginalTextBackToSession < ActiveRecord::Migration[6.0]
  def change
    add_column :sessions, :original_text, :jsonb
  end
end
