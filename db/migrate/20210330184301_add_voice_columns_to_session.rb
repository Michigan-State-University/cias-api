# frozen_string_literal: true

class AddVoiceColumnsToSession < ActiveRecord::Migration[6.0]
  def change
    add_column :sessions, :language_code, :string, default: 'en-US', null: false
    add_column :sessions, :voice_name, :string, default: 'en-US-Standard-C', null: false
  end
end
