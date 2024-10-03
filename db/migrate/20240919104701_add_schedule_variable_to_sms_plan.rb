class AddScheduleVariableToSmsPlan < ActiveRecord::Migration[6.1]
  def change
    add_column :sms_plans, :schedule_variable, :string
  end
end
