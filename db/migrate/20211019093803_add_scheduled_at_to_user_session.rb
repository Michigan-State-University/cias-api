class AddScheduledAtToUserSession < ActiveRecord::Migration[6.0]
  def change
    add_column :user_sessions, :scheduled_at, :datetime
  end
end
