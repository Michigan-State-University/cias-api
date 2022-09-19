class ChangeNotifiableIdColumnType < ActiveRecord::Migration[6.1]
  def change
    change_column :notifications, :notifiable_id, :uuid, using: "LPAD(TO_HEX(notifiable_id), 32, '0')::uuid"
  end
end
