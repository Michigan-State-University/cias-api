class AddDefaultValueToContactMessage < ActiveRecord::Migration[6.1]
  def change
    change_column_default :live_chat_navigator_setups, :contact_message, from: '', to: 'You can contact us directly by using details below'
  end
end
