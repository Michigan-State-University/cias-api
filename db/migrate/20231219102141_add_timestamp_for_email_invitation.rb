class AddTimestampForEmailInvitation < ActiveRecord::Migration[6.1]
  def change
    rename_column :predefined_user_parameters, :invitation_sent_at, :sms_invitation_sent_at
    add_column :predefined_user_parameters, :email_invitation_sent_at, :timestamp
  end
end
