class AddQuickExitToUserSession < ActiveRecord::Migration[6.1]
  def change
    add_column :user_sessions, :quick_exit, :boolean, default: false
  end
end
