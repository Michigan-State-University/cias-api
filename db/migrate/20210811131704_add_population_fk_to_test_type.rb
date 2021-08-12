class AddPopulationFkToTestType < ActiveRecord::Migration[6.0]
  def change
    add_reference :cat_mh_test_types, :cat_mh_population, index: true
  end
end
