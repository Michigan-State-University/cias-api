class AddDefaultValueToNoNavigatorAvailableMessage < ActiveRecord::Migration[6.1]
  def change
    change_column_default :live_chat_navigator_setups, :no_navigator_available_message, from: '', to: 'Welcome to our in-session support!'
  end
end
