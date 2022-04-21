class DeletePopulationColumnFromCatMhTestTypes < ActiveRecord::Migration[6.0]
  def change
    remove_column :cat_mh_test_types, :population
  end
end
