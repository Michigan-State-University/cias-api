class RemoveAbilityToCreateCatMhFromUsers < ActiveRecord::Migration[6.0]
  def change
    remove_column :users, :ability_to_create_cat_mh
  end
end
