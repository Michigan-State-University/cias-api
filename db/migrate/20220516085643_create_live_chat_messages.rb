# frozen_string_literal: true

class CreateLiveChatMessages < ActiveRecord::Migration[6.1]
  def change
    create_table :live_chat_messages, id: :uuid, default: 'uuid_generate_v4()' do |t|
      t.text :content, default: '', null: false
      t.uuid :conversation_id, null: false
      t.timestamps
    end

    add_foreign_key :live_chat_messages, :live_chat_conversations, column: :conversation_id
  end
end
