# frozen_string_literal: true

class AddSmsEligibleToPhones < ActiveRecord::Migration[8.1]
  def change
    add_column :phones, :sms_eligible, :boolean, null: false, default: false
  end
end
