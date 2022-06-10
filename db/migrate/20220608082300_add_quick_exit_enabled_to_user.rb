class AddQuickExitEnabledToUser < ActiveRecord::Migration[6.1]
  def change
    add_column :users, :quick_exit_enabled, :boolean, null: false, default: false
  end
end
