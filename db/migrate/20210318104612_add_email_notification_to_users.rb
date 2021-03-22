# frozen_string_literal: true

class AddEmailNotificationToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :email_notification, :boolean, default: true, null: false
  end
end
