# frozen_string_literal: true

class CreateLiveChatInterlocutors < ActiveRecord::Migration[6.1]
  def change
    create_table :live_chat_interlocutors, id: :uuid, default: 'uuid_generate_v4()' do |t|
      t.uuid :conversation_id, null: false
      t.uuid :user_id, null: false
      t.timestamps
    end

    add_foreign_key :live_chat_interlocutors, :live_chat_conversations, column: :conversation_id
    add_foreign_key :live_chat_interlocutors, :users, column: :user_id
  end
end
