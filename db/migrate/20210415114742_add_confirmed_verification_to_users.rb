# frozen_string_literal: true

class AddConfirmedVerificationToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :confirmed_verification, :boolean, default: false, null: false
  end
end
