# frozen_string_literal: true

class AddArchivedAtToConversations < ActiveRecord::Migration[6.1]
  def change
    add_column :live_chat_conversations, :archived_at, :datetime, null: true
    LiveChat::Conversation.reset_column_information
    LiveChat::Conversation.where(archived: true).find_each do |conversation|
      conversation.update!(archived_at: conversation.updated_at)
    end
    remove_column :live_chat_conversations, :archived
  end
end
