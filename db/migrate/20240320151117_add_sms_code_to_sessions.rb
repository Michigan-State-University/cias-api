class AddSmsCodeToSessions < ActiveRecord::Migration[6.1]
  def change
    add_column :sessions, :sms_code, :string
  end
end
