# frozen_string_literal: true

class AddDefaultValueForSchedulePayload < ActiveRecord::Migration[6.0]
  def change
    change_column_default :sms_plans, :schedule_payload, from: nil, to: 0
  end
end
