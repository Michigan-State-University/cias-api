class AddStartedFlagToUserSessions < ActiveRecord::Migration[6.1]
  def change
    add_column(:user_sessions, :started, :boolean, null: false, default: false)
  end
end
