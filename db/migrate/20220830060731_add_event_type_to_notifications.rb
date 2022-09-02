class AddEventTypeToNotifications < ActiveRecord::Migration[6.1]
  def change
    add_column :notifications, :event, :integer, default: 0, null: false
  end
end
