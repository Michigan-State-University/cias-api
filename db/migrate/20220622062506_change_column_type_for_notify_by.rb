# frozen_string_literal: true

class ChangeColumnTypeForNotifyBy < ActiveRecord::Migration[6.1]
  def up
    change_column :live_chat_navigator_setups, :notify_by, :integer, using: 'notify_by::integer', null: false, default: 0
  end
end
