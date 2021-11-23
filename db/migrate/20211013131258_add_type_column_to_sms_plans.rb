class AddTypeColumnToSmsPlans < ActiveRecord::Migration[6.0]
  def change
    add_column :sms_plans, :type, :string, null: false, default: 'SmsPlan'
  end
end
