class AddInformationAboutAutoclosedTheSession < ActiveRecord::Migration[6.1]
  def change
    add_column :sessions, :autoclose_enabled, :boolean, default: false
    add_column :sessions, :autoclose_at, :datetime
  end
end
