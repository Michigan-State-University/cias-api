class ChangeDefaultValueSmsNotification < ActiveRecord::Migration[6.0]
  def change
    change_column_default(:users, :sms_notification, from: false, to: true)
    change_column_null :users, :sms_notification, false
  end
end
