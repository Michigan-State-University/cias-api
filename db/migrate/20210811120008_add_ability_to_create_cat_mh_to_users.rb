class AddAbilityToCreateCatMhToUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :users, :ability_to_create_cat_mh, :boolean, default: false, null: false
  end
end
