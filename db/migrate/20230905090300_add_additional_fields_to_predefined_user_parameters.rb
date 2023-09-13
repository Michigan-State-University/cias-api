class AddAdditionalFieldsToPredefinedUserParameters < ActiveRecord::Migration[6.1]
  def change
    add_column(:predefined_user_parameters, :auto_invitation, :boolean, null: false, default: false)
    add_column(:predefined_user_parameters, :invitation_sent_at, :datetime)
  end
end
