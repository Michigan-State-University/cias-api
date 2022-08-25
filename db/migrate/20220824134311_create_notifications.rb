class CreateNotifications < ActiveRecord::Migration[6.1]
  def change
    create_table :notifications do |t|
      t.references :notifiable, polymorphic: true, null: false
      t.integer :notification_type, default: 0
      t.boolean :is_read, default: false
      t.string :optional_link
      t.string :title
      t.string :description
      t.string :image_url
      t.uuid :user_id, null: false

      t.timestamps
    end
  end
end
