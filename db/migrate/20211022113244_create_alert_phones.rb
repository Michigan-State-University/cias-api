class CreateAlertPhones < ActiveRecord::Migration[6.0]
  def change
    create_table :alert_phones do |t|
      t.uuid :sms_plan_id, null: false
      t.bigint :phone_id, null: false
      t.timestamps
    end

    add_foreign_key :alert_phones, :phones
    add_foreign_key :alert_phones, :sms_plans, column: :sms_plan_id
  end
end
