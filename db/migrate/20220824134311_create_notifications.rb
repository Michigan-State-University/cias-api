class CreateNotifications < ActiveRecord::Migration[6.1]
  def change
    create_table :live_chat_notifications do |t|
      t.references :notifiable, polymorphic: true, null: false
      t.string :notification_type
      t.boolean :is_read
      t.jsonb :notification_params
      t.uuid :user_id, null: false

      t.timestamps
    end
  end
end
