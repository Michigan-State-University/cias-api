# frozen_string_literal: true

class AddChatEnabledOptionToIntervention < ActiveRecord::Migration[6.1]
  def change
    add_column :interventions, :live_chat_enabled, :boolean, null: false, default: false
  end
end
