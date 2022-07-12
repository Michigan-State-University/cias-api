# frozen_string_literal: true

class AddArchivedColumnToLiveChatConversation < ActiveRecord::Migration[6.1]
  def change
    add_column :live_chat_conversations, :archived, :boolean, null: false, default: false
  end
end
