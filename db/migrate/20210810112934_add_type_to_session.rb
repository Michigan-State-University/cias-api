class AddTypeToSession < ActiveRecord::Migration[6.0]
  def change
    add_column :sessions, :type, :string, null: false, default: 'Session::Classic'
  end
end
