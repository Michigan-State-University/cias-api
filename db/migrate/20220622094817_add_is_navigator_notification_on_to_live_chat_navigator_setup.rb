class AddIsNavigatorNotificationOnToLiveChatNavigatorSetup < ActiveRecord::Migration[6.1]
  def change
    add_column :live_chat_navigator_setups, :is_navigator_notification_on, :boolean, default: true
  end
end
