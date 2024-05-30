class AddNewFieldsToSessions < ActiveRecord::Migration[6.1]
  def up
    add_column :sessions, :welcome_message, :text
    add_column :sessions, :default_response, :text
  end

  def down
    remove_column :sessions, :welcome_message
    remove_column :sessions, :default_response
  end
end
