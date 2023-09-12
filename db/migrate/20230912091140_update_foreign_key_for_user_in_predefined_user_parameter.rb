class UpdateForeignKeyForUserInPredefinedUserParameter < ActiveRecord::Migration[6.1]
  def change
    remove_foreign_key :predefined_user_parameters, :users
    add_foreign_key :predefined_user_parameters, :users, on_delete: :cascade
  end
end
