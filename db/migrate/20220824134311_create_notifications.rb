class CreateNotifications < ActiveRecord::Migration[6.1]
  def change
    create_table :notifications, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.references :notifiable, polymorphic: true, null: false
      t.boolean :is_read, default: false
      t.jsonb :data
      t.uuid :user_id, null: false, foreign_key: true
      t.uuid :conversation_id, null: false
      t.timestamps
    end

    add_foreign_key :notifications, :live_chat_conversations, column: :conversation_id

    add_index :notifications, :user_id
    add_index :notifications, :conversation_id
  end
end
