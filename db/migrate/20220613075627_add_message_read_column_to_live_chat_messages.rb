# frozen_string_literal: true

class AddMessageReadColumnToLiveChatMessages < ActiveRecord::Migration[6.1]
  def change
    add_column :live_chat_messages, :is_read, :boolean, null: false, default: false
  end
end
