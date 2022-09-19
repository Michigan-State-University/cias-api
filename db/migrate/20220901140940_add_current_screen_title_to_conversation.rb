class AddCurrentScreenTitleToConversation < ActiveRecord::Migration[6.1]
  def change
    add_column :live_chat_conversations, :current_screen_title, :string
  end
end
