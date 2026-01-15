class AddNewFieldsAllowingToDefineTimeOfTheSmsMessageByResearcher < ActiveRecord::Migration[7.2]
  def change
    add_column :sms_plans, :sms_send_time_type, :string, null: false, default: 'preferred_by_participant'
    add_column :sms_plans, :sms_send_time_details, :jsonb, default: {}
  end
end
