# frozen_string_literal: true

class AddContentCiphertextToLiveChatMessages < ActiveRecord::Migration[6.1]
  def change
    migrate_contents = LiveChat::Message.all.map do |message|
      [message.id, message.content]
    end

    rename_column :live_chat_messages, :content, :content_ciphertext

    LiveChat::Message.reset_column_information
    migrate_contents.each do |(message_id, message_content)|
      LiveChat::Message.find(message_id).update!(content: message_content)
    end
  end
end
