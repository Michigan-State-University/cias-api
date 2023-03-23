class AddNewFieldsToNavigatorSetup < ActiveRecord::Migration[6.1]
  def change
    add_column :live_chat_navigator_setups, :contact_message, :string
    add_column :phones, :communication_way, :string
    execute <<-SQL.squish
        update phones set "communication_way" = 'call' where "navigator_setup_id" is not null;
    SQL
  end
end
