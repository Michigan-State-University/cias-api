class AddExternalIdToPredefinedUsers < ActiveRecord::Migration[6.1]
  def change
    add_column :predefined_user_parameters, :external_id, :string
  end
end
