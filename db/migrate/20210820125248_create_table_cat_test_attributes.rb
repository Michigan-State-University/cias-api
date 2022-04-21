class CreateTableCatTestAttributes < ActiveRecord::Migration[6.0]
  def change
    create_table :cat_mh_test_attributes do |t|
      t.string :name
      t.string :variable_type
      t.string :range
      t.timestamps
    end

    create_table :cat_mh_variables do |t|
      t.belongs_to :cat_mh_test_attribute
      t.belongs_to :cat_mh_test_type
      t.timestamps
    end
  end
end
