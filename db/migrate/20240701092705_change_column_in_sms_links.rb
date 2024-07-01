class ChangeColumnInSmsLinks < ActiveRecord::Migration[6.1]
  def change
    add_column :sms_links, :variable, :string, null: false
    add_index :sms_links, [:sms_plan_id, :variable], unique: true
    remove_column :sms_links, :variable_number
  end
end
