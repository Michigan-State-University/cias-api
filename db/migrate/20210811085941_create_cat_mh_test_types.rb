class CreateCatMhTestTypes < ActiveRecord::Migration[6.0]
  def change
    create_table :cat_mh_test_types do |t|
      t.string :short_name
      t.string :name
      t.string :population # normal, perinatal or criminal justice

      t.timestamps
    end
  end
end
