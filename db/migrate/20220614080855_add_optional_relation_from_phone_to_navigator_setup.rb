# frozen_string_literal: true

class AddOptionalRelationFromPhoneToNavigatorSetup < ActiveRecord::Migration[6.1]
  def change
    add_column :phones, :navigator_setup_id, :uuid, null: true
    add_foreign_key :phones, :live_chat_navigator_setups, column: :navigator_setup_id
  end
end
