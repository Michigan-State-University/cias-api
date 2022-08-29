class CreateNotifications < ActiveRecord::Migration[6.1]
  def change
    create_table :notifications, id: :uuid, default: 'uuid_generate_v4()', null: false do |t|
      t.references :notifiable, polymorphic: true, null: false
      t.boolean :is_read, default: false
      t.jsonb :data
      t.uuid :user_id, null: false, foreign_key: true
      t.timestamps
    end

    add_index :notifications, :user_id
  end
end
