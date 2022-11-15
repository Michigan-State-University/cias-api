# frozen_string_literal: true

class AddConversationLocationHistoryToConversations < ActiveRecord::Migration[6.1]
  def change
    add_column :live_chat_conversations, :participant_location_history, :string, array: true, default: [], null: false
  end
end
