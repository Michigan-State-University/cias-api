class AddDaysAfterDateVariableNameToSessions < ActiveRecord::Migration[6.0]
  def change
    add_column :sessions, :days_after_date_variable_name, :string
  end
end
