# frozen_string_literal: true

class AddSmsPhoneToUserSessions < ActiveRecord::Migration[7.2]
  def change
    add_column :user_sessions, :sms_phone_prefix, :string
    add_column :user_sessions, :sms_phone_number_ciphertext, :text
    add_column :user_sessions, :sms_phone_number_bidx, :string

    add_index :user_sessions, :sms_phone_number_bidx
  end
end
