# frozen_string_literal: true

class AddReminderColumnsToPredefinedUserParameters < ActiveRecord::Migration[8.1]
  def change
    change_table :predefined_user_parameters, bulk: true do |t|
      t.datetime :first_opened_at
      t.datetime :last_reminder_sent_at
    end
  end
end
