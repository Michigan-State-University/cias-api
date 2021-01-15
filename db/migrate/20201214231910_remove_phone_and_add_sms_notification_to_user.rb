# frozen_string_literal: true

class RemovePhoneAndAddSmsNotificationToUser < ActiveRecord::Migration[6.0]
  # rubocop:disable Rails/BulkChangeTable
  def up
    remove_column :users, :phone
    add_column :users, :sms_notification, :boolean, default: false
  end

  def down
    add_column :users, :phone, :string
    remove_column :users, :sms_notification
  end
  # rubocop:enable Rails/BulkChangeTable
end
