# frozen_string_literal: true

class AddVerificationLoggingDataToUsers < ActiveRecord::Migration[6.0]
  def change
    change_table :users, bulk: true do |t|
      t.string :verification_code
      t.datetime :verification_code_created_at
    end
  end
end
