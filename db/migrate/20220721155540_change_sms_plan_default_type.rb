class ChangeSmsPlanDefaultType < ActiveRecord::Migration[6.1]
  def up
    change_column_default :sms_plans, :type, "SmsPlan::Normal"
    SmsPlan.connection.execute("UPDATE sms_plans SET type='SmsPlan::Normal' where type='SmsPlan'")
  end

  def down
    change_column_default :sms_plans, :type, "SmsPlan"
  end
end
