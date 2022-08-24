class CreateNotifications < ActiveRecord::Migration[6.1]
  def change
    create_table :live_chat_notifications do |t|
      t.references :object, polymorphic: true, null: false
      t.timestamp :timestamp
      t.string :type
      t.boolean :isRead
      t.string :optional_link
      t.string :title
      t.text :description
      t.string :image_src
      t.uuid :user_id, null: false

      t.timestamps
    end
  end
end
