# frozen_string_literal: true

class AddSenderIdFkToMessages < ActiveRecord::Migration[6.1]
  def change
    add_column :live_chat_messages, :live_chat_interlocutor_id, :uuid, null: false
    add_foreign_key :live_chat_messages, :live_chat_interlocutors, column: :live_chat_interlocutor_id
  end
end
