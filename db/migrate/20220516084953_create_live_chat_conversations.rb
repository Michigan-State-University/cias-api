# frozen_string_literal: true

class CreateLiveChatConversations < ActiveRecord::Migration[6.1]
  def change
    create_table :live_chat_conversations, id: :uuid, default: 'uuid_generate_v4()' do |t|
      t.timestamps
    end
  end
end
