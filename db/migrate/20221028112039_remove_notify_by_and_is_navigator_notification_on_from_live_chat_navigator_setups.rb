class RemoveNotifyByAndIsNavigatorNotificationOnFromLiveChatNavigatorSetups < ActiveRecord::Migration[6.1]
  def change
    remove_column :live_chat_navigator_setups, :notify_by, :integer
    remove_column :live_chat_navigator_setups, :is_navigator_notification_on, :boolean
  end
end
