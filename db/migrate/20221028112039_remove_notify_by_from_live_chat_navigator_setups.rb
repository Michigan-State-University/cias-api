class RemoveNotifyByFromLiveChatNavigatorSetups < ActiveRecord::Migration[6.1]
  def change
    remove_column :live_chat_navigator_setups, :notify_by, :integer
  end
end
