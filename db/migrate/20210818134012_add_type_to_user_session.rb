class AddTypeToUserSession < ActiveRecord::Migration[6.0]
  def change
    add_column :user_sessions, :type, :string, null: false, default: 'UserSession::Classic'
    add_column :user_sessions, :cat_interview_id, :integer
    add_column :user_sessions, :identifier, :string
    add_column :user_sessions, :signature, :string
    add_column :user_sessions,:jsession_id, :string
    add_column :user_sessions, :awselb, :string
  end
end
