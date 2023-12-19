class AddNewFieldsToPredefinedUserParameters < ActiveRecord::Migration[6.1]
  def change
    add_column :predefined_user_parameters, :sms_notification, :boolean, default: false
    add_column :predefined_user_parameters, :email_notification, :boolean, default: false
  end
end
